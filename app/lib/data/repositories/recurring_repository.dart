import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/ids.dart';
import '../../core/local_date.dart';
import '../../domain/enums.dart';
import '../db/database.dart';
import 'ledger_repository.dart';
import 'outbox_writer.dart';

/// 반복 주기. [code]가 `recurring_rules.frequency`에 저장되는 값이다.
enum RecurringFrequency {
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurringFrequency(this.code);
  final String code;

  /// 모르는 값이면 매달로 본다(다른 판의 앱이 만든 규칙을 읽다가 멈추지 않게).
  static RecurringFrequency fromCode(String code) =>
      values.firstWhere((v) => v.code == code, orElse: () => monthly);
}

/// 반복 규칙이 만들 거래의 틀. `recurring_rules.template`에 JSON으로 둔다.
///
/// 키는 `docs/SPEC.md` 7.13의 것(`type`, `amount`, `account_id`, `to_account_id`,
/// `counterparty`, `category_id`, `memo`)에 `anchor_day`를 더했다. 매달 31일 규칙이
/// 2월에 28일로 당겨진 뒤에도 3월에는 31일로 돌아가려면 처음 고른 날을 알아야 하는데,
/// `next_run_on`만으로는 알 수 없다.
class RecurringTemplate {
  const RecurringTemplate({
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.counterparty,
    this.categoryId,
    this.memo,
    this.anchorDay,
  });

  /// 읽을 수 없는 틀이면 null.
  static RecurringTemplate? tryParse(Map<String, Object?> json) {
    final type = TxType.values.where((t) => t.code == json['type']).firstOrNull;
    final amount = json['amount'];
    final accountId = json['account_id'];
    if (type == null || amount is! num || accountId is! String) return null;
    final anchor = json['anchor_day'];
    return RecurringTemplate(
      type: type,
      amount: amount.toInt(),
      accountId: accountId,
      toAccountId: json['to_account_id'] as String?,
      counterparty: json['counterparty'] as String?,
      categoryId: json['category_id'] as String?,
      memo: json['memo'] as String?,
      anchorDay: anchor is num && anchor >= 1 && anchor <= 31
          ? anchor.toInt()
          : null,
    );
  }

  final TxType type;

  /// 원 단위.
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String? counterparty;
  final String? categoryId;
  final String? memo;

  /// 매달 · 매년 규칙에서 사용자가 고른 날(1–31). 없으면 `next_run_on`의 날을 쓴다.
  final int? anchorDay;

  RecurringTemplate withAnchorDay(int? day) => RecurringTemplate(
    type: type,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    counterparty: counterparty,
    categoryId: categoryId,
    memo: memo,
    anchorDay: day,
  );

  Map<String, Object?> toJson() {
    String? text(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    final transfer = type == TxType.transfer;
    return {
      'type': type.code,
      'amount': amount,
      'account_id': accountId,
      'to_account_id': transfer ? toAccountId : null,
      // 이체에는 상대방과 분류를 두지 않는다(거래와 같은 규칙).
      'counterparty': transfer ? null : text(counterparty),
      'category_id': transfer ? null : categoryId,
      'memo': text(memo),
      'anchor_day': ?anchorDay,
    };
  }
}

/// 반복 규칙을 만들거나 고칠 때 넘기는 값.
class RecurringRuleInput {
  const RecurringRuleInput({
    required this.template,
    required this.frequency,
    required this.nextRunOn,
    this.intervalCount = 1,
    this.endOn,
    this.autoPost = false,
    this.isActive = true,
  });

  final RecurringTemplate template;
  final RecurringFrequency frequency;

  /// 몇 주 · 몇 달 · 몇 해마다(1 이상).
  final int intervalCount;

  /// 다음에 거래를 만들 날.
  final LocalDate nextRunOn;

  /// 이 날까지만 만든다. null이면 끝이 없다.
  final LocalDate? endOn;

  /// true면 바로 확정된 거래로, false면 확인 필요로 만든다.
  final bool autoPost;
  final bool isActive;
}

/// [current] 다음에 규칙이 도는 날.
///
/// 매달 · 매년은 [anchorDay]에 맞추고, 그 달에 없는 날이면 마지막 날로 당긴다.
LocalDate nextRecurrence(
  LocalDate current,
  RecurringFrequency frequency,
  int intervalCount, {
  int? anchorDay,
}) {
  final interval = intervalCount < 1 ? 1 : intervalCount;
  if (frequency == RecurringFrequency.weekly) {
    return current.addDays(7 * interval);
  }
  final months = frequency == RecurringFrequency.yearly
      ? 12 * interval
      : interval;
  final moved = LocalDate(current.year, current.month, 1).addMonths(months);
  final day = anchorDay ?? current.day;
  final last = LocalDate.daysInMonth(moved.year, moved.month);
  return LocalDate(moved.year, moved.month, day > last ? last : day);
}

/// 반복 규칙의 읽기 · 쓰기와 밀린 거래 만들기(`docs/SPEC.md` 7.13).
class RecurringRepository {
  RecurringRepository(this.ledger, {String Function()? idGenerator})
    : _newId = idGenerator ?? newRowId;

  /// 한 번 돌 때 만드는 거래의 한도. 오래 쉬었다 켜도 한꺼번에 쏟아지지 않게 한다.
  /// 남은 것은 다음에 돌 때 이어서 만든다.
  static const maxPerRun = 24;

  /// 반복 거래의 ID를 계산하는 이름 공간. 모든 기기가 같은 값을 써야 한다.
  static final _namespace = const Uuid().v5(
    Namespace.url.value,
    'https://github.com/kimhershey/gagyebu#recurring',
  );

  final LedgerRepository ledger;
  final String Function() _newId;

  AppDatabase get db => ledger.db;
  OutboxWriter get outbox => ledger.outbox;

  /// 규칙 [ruleId]가 [date]에 만드는 거래의 ID(UUIDv5).
  ///
  /// 두 기기가 같은 날짜의 거래를 따로 만들어도 같은 행이 되어 한 건만 남는다.
  static String transactionIdFor(String ruleId, LocalDate date) =>
      const Uuid().v5(_namespace, '$ruleId:$date');

  SimpleSelectStatement<$RecurringRulesTable, RecurringRuleRow> _rulesQuery(
    String ledgerId,
  ) => db.select(db.recurringRules)
    ..where((r) => r.ledgerId.equals(ledgerId) & r.deletedAt.isNull())
    ..orderBy([
      (r) => OrderingTerm.asc(r.nextRunOn),
      (r) => OrderingTerm.asc(r.id),
    ]);

  /// 규칙을 다음 날짜가 가까운 순서로.
  Stream<List<RecurringRuleRow>> watchRules(String ledgerId) =>
      _rulesQuery(ledgerId).watch();

  Future<List<RecurringRuleRow>> rules(String ledgerId) =>
      _rulesQuery(ledgerId).get();

  Future<RecurringRuleRow?> _live(String id) => (db.select(
    db.recurringRules,
  )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();

  RecurringRulesCompanion _companion(RecurringRuleInput input, DateTime now) {
    final template = input.template;
    if (template.amount <= 0) throw ArgumentError('금액은 0보다 커야 합니다');
    if (input.intervalCount < 1) throw ArgumentError('간격은 1 이상이어야 합니다');
    if (template.type == TxType.transfer) {
      final to = template.toAccountId;
      if (to == null) throw ArgumentError('이체에는 받는 자산이 필요합니다');
      if (to == template.accountId) {
        throw ArgumentError('같은 자산으로는 이체할 수 없습니다');
      }
    }
    // 매주 규칙에는 '고른 날'이 뜻이 없다. 매달 · 매년은 틀에 없으면 다음 날짜의 날로 둔다.
    final anchored = input.frequency == RecurringFrequency.weekly
        ? template.withAnchorDay(null)
        : template.withAnchorDay(template.anchorDay ?? input.nextRunOn.day);
    return RecurringRulesCompanion(
      template: Value(anchored.toJson()),
      frequency: Value(input.frequency.code),
      intervalCount: Value(input.intervalCount),
      nextRunOn: Value(input.nextRunOn),
      endOn: Value(input.endOn),
      autoPost: Value(input.autoPost),
      isActive: Value(input.isActive),
      clientUpdatedAt: Value(now),
      updatedAt: Value(now),
    );
  }

  /// 규칙을 더하고 그 ID를 돌려준다.
  Future<String> addRule(String ledgerId, RecurringRuleInput input) =>
      db.transaction(() async {
        final now = outbox.now();
        final id = _newId();
        await db
            .into(db.recurringRules)
            .insert(
              _companion(input, now).copyWith(
                id: Value(id),
                ledgerId: Value(ledgerId),
                createdAt: Value(now),
              ),
            );
        await outbox.enqueue(ledgerId, 'recurring_rules', id, 'upsert', 0, now);
        return id;
      });

  /// 규칙 [id]를 [input]으로 고친다.
  Future<void> updateRule(String id, RecurringRuleInput input) =>
      db.transaction(() async {
        final existing = await _live(id);
        if (existing == null) throw StateError('없는 규칙입니다: $id');
        final now = outbox.now();
        await (db.update(
          db.recurringRules,
        )..where((r) => r.id.equals(id))).write(_companion(input, now));
        await outbox.enqueue(
          existing.ledgerId,
          'recurring_rules',
          id,
          'upsert',
          existing.version,
          now,
        );
      });

  /// 규칙을 켜거나 끈다. 꺼 둔 규칙은 거래를 만들지 않는다.
  Future<void> setActive(String id, {required bool active}) => db.transaction(
    () async {
      final existing = await _live(id);
      if (existing == null) throw StateError('없는 규칙입니다: $id');
      if (existing.isActive == active) return;
      final now = outbox.now();
      await (db.update(db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(
          isActive: Value(active),
          clientUpdatedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await outbox.enqueue(
        existing.ledgerId,
        'recurring_rules',
        id,
        'upsert',
        existing.version,
        now,
      );
    },
  );

  /// 규칙을 지운다. 이미 만든 거래는 남는다.
  Future<void> deleteRule(String id) => db.transaction(() async {
    final existing = await _live(id);
    if (existing == null) return;
    await outbox.softDelete(
      'recurring_rules',
      existing.ledgerId,
      id,
      existing.version,
    );
  });

  /// 다음 날짜가 [today]이거나 그 전인 규칙마다 밀린 만큼 거래를 만들고 다음 날짜를
  /// 옮긴다. 새로 만든 거래의 수를 돌려준다.
  ///
  /// 한 번에 [maxPerRun]건까지만 만든다. 남은 것은 다음에 부를 때 이어서 만든다.
  /// 같은 날짜의 거래가 이미 있으면(다른 기기가 먼저 만들었거나, 만든 뒤에 지웠으면)
  /// 다시 만들지 않고 날짜만 옮긴다.
  Future<int> runDue(String ledgerId, LocalDate today) async {
    var created = 0;
    for (final rule in await rules(ledgerId)) {
      if (created >= maxPerRun) break;
      if (!rule.isActive || rule.nextRunOn > today) continue;
      created += await _runRule(rule.id, today, maxPerRun - created);
    }
    return created;
  }

  Future<int> _runRule(String id, LocalDate today, int room) => db.transaction(
    () async {
      // 트랜잭션 안에서 다시 읽는다. 목록을 읽은 뒤에 바뀌었을 수 있다.
      final rule = await _live(id);
      if (rule == null || !rule.isActive) return 0;
      final template = RecurringTemplate.tryParse(rule.template);
      if (template == null) return 0;
      // 틀이 가리키는 자산이 지워졌으면 거래를 만들 수 없다. 날짜도 옮기지 않고 그대로
      // 둔다(화면이 알려 주고, 자산을 다시 고르면 밀린 것부터 만든다).
      final accounts = {
        for (final account in await ledger.accounts(rule.ledgerId)) account.id,
      };
      if (!accounts.contains(template.accountId)) return 0;
      if (template.type == TxType.transfer &&
          !accounts.contains(template.toAccountId)) {
        return 0;
      }
      final liveCategory = template.categoryId == null
          ? null
          : await (db.select(db.categories)..where(
                  (c) =>
                      c.id.equals(template.categoryId!) & c.deletedAt.isNull(),
                ))
                .getSingleOrNull();

      final frequency = RecurringFrequency.fromCode(rule.frequency);
      final end = rule.endOn;
      var next = rule.nextRunOn;
      var created = 0;
      while (next <= today && (end == null || next <= end)) {
        final txId = transactionIdFor(rule.id, next);
        if (await ledger.transactionById(txId) == null) {
          if (created >= room) break;
          await ledger.addTransaction(
            rule.ledgerId,
            TransactionInput(
              type: template.type,
              occurredOn: next,
              amount: template.amount,
              accountId: template.accountId,
              toAccountId: template.toAccountId,
              counterparty: template.counterparty,
              // 지워진 분류는 분류 없음으로 만든다.
              categoryId: liveCategory?.id,
              memo: template.memo,
              source: TxSource.recurring,
              status: rule.autoPost ? TxStatus.confirmed : TxStatus.needsReview,
            ),
            id: txId,
          );
          created++;
        }
        next = nextRecurrence(
          next,
          frequency,
          rule.intervalCount,
          anchorDay: template.anchorDay,
        );
      }
      if (next != rule.nextRunOn) {
        final now = outbox.now();
        await (db.update(
          db.recurringRules,
        )..where((r) => r.id.equals(rule.id))).write(
          RecurringRulesCompanion(
            nextRunOn: Value(next),
            clientUpdatedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await outbox.enqueue(
          rule.ledgerId,
          'recurring_rules',
          rule.id,
          'upsert',
          rule.version,
          now,
        );
      }
      return created;
    },
  );
}

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(repositoryProvider)),
);
