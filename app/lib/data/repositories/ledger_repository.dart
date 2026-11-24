import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../core/local_date.dart';
import '../../domain/default_seed.dart';
import '../../domain/enums.dart';
import '../../domain/month_period.dart';
import '../../domain/month_summary.dart';
import '../db/database.dart';
import 'outbox_writer.dart';

/// 거래 한 건을 저장할 때 넘기는 값.
class TransactionInput {
  const TransactionInput({
    required this.type,
    required this.occurredOn,
    required this.amount,
    required this.accountId,
    this.occurredTime,
    this.toAccountId,
    this.counterparty,
    this.categoryId,
    this.memo,
    this.installmentMonths,
    this.balanceAfter,
    this.currency,
    this.originalAmount,
    this.source = TxSource.manual,
    this.aiModel,
    this.canceled = false,
    this.status = TxStatus.confirmed,
  });

  final TxType type;
  final LocalDate occurredOn;

  /// 'HH:mm'
  final String? occurredTime;

  /// 원 단위 정수
  final int amount;

  /// 돈이 나가거나 들어온 내 자산
  final String accountId;

  /// 이체일 때 받는 쪽 내 자산
  final String? toAccountId;

  /// 상대방. 지출이면 받는 쪽, 수입이면 보낸 쪽. 이체에는 쓰지 않는다.
  final String? counterparty;
  final String? categoryId;
  final String? memo;
  final int? installmentMonths;
  final int? balanceAfter;
  final String? currency;
  final double? originalAmount;
  final TxSource source;
  final String? aiModel;

  /// 전액 취소된 거래. 집계에서 뺍니다.
  final bool canceled;

  /// 확인이 더 필요한 거래면 [TxStatus.needsReview]. 내역에서 모아 본다.
  final TxStatus status;
}

/// 화면에 보여 줄 거래: 행에 자산 · 분류 이름을 붙인 것.
class TransactionView {
  const TransactionView({
    required this.row,
    required this.accountName,
    this.toAccountName,
    this.categoryName,
  });

  final TxRow row;
  final String accountName;
  final String? toAccountName;
  final String? categoryName;

  /// 상대방. 입금이면 보낸 쪽, 출금이면 받는 쪽, 이체는 없다.
  String? get counterparty => switch (row.type) {
    TxType.income => row.sender,
    TxType.expense => row.receiver,
    TxType.transfer => null,
  };

  /// 목록에 보일 한 줄 제목.
  String get title {
    final party = counterparty;
    if (party != null && party.isNotEmpty) return party;
    if (row.type == TxType.transfer) {
      return '$accountName → ${toAccountName ?? ''}';
    }
    final memo = row.memo;
    if (memo != null && memo.isNotEmpty) return memo;
    return categoryName ?? '내용 없음';
  }

  bool get isCanceled => row.canceledAt != null;

  /// 수지에 미치는 금액. 지출은 음수, 수입은 양수, 이체와 취소는 0.
  int get signedAmount {
    if (isCanceled) return 0;
    return switch (row.type) {
      TxType.income => row.amount,
      TxType.expense => -row.amount,
      TxType.transfer => 0,
    };
  }
}

/// 자산과 현재 잔액.
class AccountBalance {
  const AccountBalance({required this.account, required this.balance});

  final AccountRow account;

  /// 시작 잔액 + 수입 − 지출 ± 이체.
  final int balance;
}

/// 가계부 데이터의 읽기와 쓰기.
///
/// 모든 쓰기는 로컬 DB에 먼저 기록하고 같은 트랜잭션에서 변경 대기열(outbox)에 올린다.
/// 서버로 보내는 일은 동기화 엔진이 맡는다.
class LedgerRepository {
  LedgerRepository(
    this.db, {
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : outbox = OutboxWriter(db, clock: clock),
       _newId = idGenerator ?? newRowId;

  final AppDatabase db;

  /// 변경 대기열에 올리는 도구. 다른 저장소도 이것을 받아 쓴다.
  final OutboxWriter outbox;
  final String Function() _newId;

  DateTime _now() => outbox.now();

  // ------------------------------------------------------------------ 가계부

  /// 가계부가 없으면 로컬 가계부를 만들고 기본 분류와 현금 자산을 넣는다.
  ///
  /// 로그인 전에도 앱을 쓸 수 있게 하는 경로다. 로그인하면 서버가 만든 가계부로 옮긴다.
  Future<String> ensureLocalLedger() => db.transaction(() async {
    final existing =
        await (db.select(db.ledgers)
              ..where((l) => l.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;

    final now = _now();
    final ledgerId = _newId();
    await db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            id: ledgerId,
            name: defaultLedgerName,
            clientUpdatedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    for (final kind in CategoryKind.values) {
      var order = 10;
      for (final name in defaultCategoryNames(kind)) {
        await db
            .into(db.categories)
            .insert(
              CategoriesCompanion.insert(
                id: _newId(),
                ledgerId: ledgerId,
                kind: kind,
                name: name,
                sortOrder: Value(order),
                clientUpdatedAt: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        order += 10;
      }
    }

    final cashId = _newId();
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: cashId,
            ledgerId: ledgerId,
            name: defaultCashAccountName,
            kind: AccountKind.cash,
            clientUpdatedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.profiles)
        .insert(
          ProfilesCompanion.insert(
            // 로그인 전에는 인증 사용자 ID가 없어 가계부 ID를 빌려 쓴다.
            id: ledgerId,
            ledgerId: ledgerId,
            defaultAccountId: Value(cashId),
            clientUpdatedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return ledgerId;
  });

  SimpleSelectStatement<$ProfilesTable, ProfileRow> _profileQuery(
    String ledgerId,
  ) => db.select(db.profiles)
    ..where((p) => p.ledgerId.equals(ledgerId) & p.deletedAt.isNull())
    ..limit(1);

  Stream<ProfileRow?> watchProfile(String ledgerId) =>
      _profileQuery(ledgerId).watchSingleOrNull();

  Future<ProfileRow?> profile(String ledgerId) =>
      _profileQuery(ledgerId).getSingleOrNull();

  Future<void> setMonthStartDay(String ledgerId, int day) async {
    if (day < 1 || day > 28) {
      throw ArgumentError.value(day, 'day', '1–28이어야 한다');
    }
    await db.transaction(() async {
      final profile =
          await (db.select(db.profiles)
                ..where(
                  (p) => p.ledgerId.equals(ledgerId) & p.deletedAt.isNull(),
                )
                ..limit(1))
              .getSingle();
      final now = _now();
      await (db.update(
        db.profiles,
      )..where((p) => p.id.equals(profile.id))).write(
        ProfilesCompanion(
          monthStartDay: Value(day),
          clientUpdatedAt: Value(now),
        ),
      );
      await _enqueue(
        ledgerId,
        'profiles',
        profile.id,
        'upsert',
        profile.version,
        now,
      );
    });
  }

  // ------------------------------------------------------------------ 자산

  SimpleSelectStatement<$AccountsTable, AccountRow> _accountsQuery(
    String ledgerId,
  ) => db.select(db.accounts)
    ..where((a) => a.ledgerId.equals(ledgerId) & a.deletedAt.isNull())
    ..orderBy([
      (a) => OrderingTerm.asc(a.sortOrder),
      (a) => OrderingTerm.asc(a.createdAt),
    ]);

  Stream<List<AccountRow>> watchAccounts(String ledgerId) =>
      _accountsQuery(ledgerId).watch();

  Future<List<AccountRow>> accounts(String ledgerId) =>
      _accountsQuery(ledgerId).get();

  Future<String> addAccount({
    required String ledgerId,
    required String name,
    required AccountKind kind,
    String? institution,
    List<String> matchHints = const [],
    int openingBalance = 0,
    int? billingDay,
    String? paymentAccountId,
  }) => db.transaction(() async {
    final now = _now();
    final id = _newId();
    final maxOrder =
        await (db.selectOnly(db.accounts)
              ..addColumns([db.accounts.sortOrder.max()])
              ..where(db.accounts.ledgerId.equals(ledgerId)))
            .map((row) => row.read(db.accounts.sortOrder.max()))
            .getSingle();
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            name: name.trim(),
            kind: kind,
            institution: Value(_blankToNull(institution)),
            matchHints: Value(matchHints),
            openingBalance: Value(openingBalance),
            billingDay: Value(billingDay),
            paymentAccountId: Value(paymentAccountId),
            sortOrder: Value((maxOrder ?? 0) + 10),
            clientUpdatedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _enqueue(ledgerId, 'accounts', id, 'upsert', 0, now);
    return id;
  });

  /// 자산을 지운다. 그 자산을 쓰는 거래가 있으면 [StateError].
  Future<void> deleteAccount(String id) => db.transaction(() async {
    final account = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(id))).getSingle();
    final t = db.ledgerTransactions;
    final used =
        await (db.selectOnly(t)
              ..addColumns([t.id.count()])
              ..where(
                (t.accountId.equals(id) | t.toAccountId.equals(id)) &
                    t.deletedAt.isNull(),
              ))
            .map((row) => row.read(t.id.count()) ?? 0)
            .getSingle();
    if (used > 0) {
      throw StateError('이 자산을 쓰는 거래가 $used건 있어 지울 수 없습니다');
    }
    await _softDelete('accounts', account.ledgerId, id, account.version);
  });

  /// 자산별 현재 잔액.
  Stream<List<AccountBalance>> watchAccountBalances(String ledgerId) {
    final query = db.customSelect(
      '''
      SELECT a.id AS id,
             a.opening_balance
               + COALESCE((SELECT SUM(CASE t.type WHEN 'income' THEN t.amount ELSE -t.amount END)
                           FROM transactions t
                           WHERE t.account_id = a.id AND t.deleted_at IS NULL
                             AND t.canceled_at IS NULL), 0)
               + COALESCE((SELECT SUM(t.amount)
                           FROM transactions t
                           WHERE t.to_account_id = a.id AND t.type = 'transfer'
                             AND t.deleted_at IS NULL AND t.canceled_at IS NULL), 0)
               AS balance
      FROM accounts a
      WHERE a.ledger_id = ?1 AND a.deleted_at IS NULL
      ''',
      variables: [Variable.withString(ledgerId)],
      readsFrom: {db.accounts, db.ledgerTransactions},
    );
    return query.watch().asyncMap((rows) async {
      final balances = {
        for (final row in rows)
          row.read<String>('id'): row.read<int>('balance'),
      };
      final all = await accounts(ledgerId);
      return [
        for (final account in all)
          AccountBalance(
            account: account,
            balance: balances[account.id] ?? account.openingBalance,
          ),
      ];
    });
  }

  // ------------------------------------------------------------------ 분류

  SimpleSelectStatement<$CategoriesTable, CategoryRow> _categoriesQuery(
    String ledgerId,
  ) => db.select(db.categories)
    ..where((c) => c.ledgerId.equals(ledgerId) & c.deletedAt.isNull())
    ..orderBy([
      (c) => OrderingTerm.asc(c.kind),
      (c) => OrderingTerm.asc(c.sortOrder),
    ]);

  Stream<List<CategoryRow>> watchCategories(String ledgerId) =>
      _categoriesQuery(ledgerId).watch();

  Future<List<CategoryRow>> categories(String ledgerId) =>
      _categoriesQuery(ledgerId).get();

  Future<String> addCategory({
    required String ledgerId,
    required CategoryKind kind,
    required String name,
    String? parentId,
  }) => db.transaction(() async {
    final now = _now();
    final id = _newId();
    final c = db.categories;
    final maxOrder =
        await (db.selectOnly(c)
              ..addColumns([c.sortOrder.max()])
              ..where(c.ledgerId.equals(ledgerId) & c.kind.equalsValue(kind)))
            .map((row) => row.read(c.sortOrder.max()))
            .getSingle();
    await db
        .into(c)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            kind: kind,
            name: name.trim(),
            parentId: Value(parentId),
            sortOrder: Value((maxOrder ?? 0) + 10),
            clientUpdatedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _enqueue(ledgerId, 'categories', id, 'upsert', 0, now);
    return id;
  });

  /// 분류를 지운다. 이 분류를 쓰던 거래는 분류 없음이 된다.
  Future<void> deleteCategory(String id) => db.transaction(() async {
    final category = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingle();
    final now = _now();
    final t = db.ledgerTransactions;
    final affected = await (db.select(
      t,
    )..where((x) => x.categoryId.equals(id) & x.deletedAt.isNull())).get();
    for (final tx in affected) {
      await (db.update(t)..where((x) => x.id.equals(tx.id))).write(
        LedgerTransactionsCompanion(
          categoryId: const Value(null),
          clientUpdatedAt: Value(now),
        ),
      );
      await _enqueue(
        tx.ledgerId,
        'transactions',
        tx.id,
        'upsert',
        tx.version,
        now,
      );
    }
    await _softDelete('categories', category.ledgerId, id, category.version);
  });

  // ------------------------------------------------------------------ 거래

  /// [from] 이상 [toExclusive] 미만의 거래를 최근 순으로.
  Stream<List<TransactionView>> watchTransactions(
    String ledgerId, {
    required LocalDate from,
    required LocalDate toExclusive,
    String? search,
  }) {
    final t = db.ledgerTransactions;
    final a = db.accounts;
    final toA = db.alias(db.accounts, 'to_account');
    final c = db.categories;

    var condition =
        t.ledgerId.equals(ledgerId) &
        t.deletedAt.isNull() &
        t.occurredOn.isBiggerOrEqualValue(from.toString()) &
        t.occurredOn.isSmallerThanValue(toExclusive.toString());
    final term = search?.trim() ?? '';
    if (term.isNotEmpty) {
      final like = '%${_escapeLike(term)}%';
      condition =
          condition &
          (t.sender.like(like, escapeChar: r'\') |
              t.receiver.like(like, escapeChar: r'\') |
              t.memo.like(like, escapeChar: r'\') |
              c.name.like(like, escapeChar: r'\'));
    }

    final query =
        db.select(t).join([
            leftOuterJoin(a, a.id.equalsExp(t.accountId)),
            leftOuterJoin(toA, toA.id.equalsExp(t.toAccountId)),
            leftOuterJoin(c, c.id.equalsExp(t.categoryId)),
          ])
          ..where(condition)
          ..orderBy([
            OrderingTerm.desc(t.occurredOn),
            OrderingTerm(
              expression: t.occurredTime,
              mode: OrderingMode.desc,
              nulls: NullsOrder.last,
            ),
            OrderingTerm.desc(t.id),
          ]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          TransactionView(
            row: row.readTable(t),
            accountName: row.readTableOrNull(a)?.name ?? '(지워진 자산)',
            toAccountName: row.readTableOrNull(toA)?.name,
            categoryName: row.readTableOrNull(c)?.name,
          ),
      ],
    );
  }

  Future<TxRow?> transactionById(String id) => (db.select(
    db.ledgerTransactions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 거래를 더한다.
  ///
  /// [id]를 주면 그 ID로 만든다. 같은 ID의 거래가 이미 있으면(지운 것도 포함) 아무것도
  /// 하지 않는다. 반복 거래처럼 두 기기가 같은 거래를 만들 수 있을 때 쓴다.
  Future<String> addTransaction(
    String ledgerId,
    TransactionInput input, {
    String? id,
  }) => db.transaction(() async {
    if (id != null && await transactionById(id) != null) return id;
    final now = _now();
    final txId = id ?? _newId();
    final companion = await _companionFor(ledgerId, input, now);
    await db
        .into(db.ledgerTransactions)
        .insert(
          companion.copyWith(
            id: Value(txId),
            ledgerId: Value(ledgerId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _enqueue(ledgerId, 'transactions', txId, 'upsert', 0, now);
    return txId;
  });

  Future<void> updateTransaction(String id, TransactionInput input) =>
      db.transaction(() async {
        final existing = await transactionById(id);
        if (existing == null || existing.deletedAt != null) {
          throw StateError('없는 거래입니다: $id');
        }
        final now = _now();
        final companion = await _companionFor(existing.ledgerId, input, now);
        await (db.update(
          db.ledgerTransactions,
        )..where((t) => t.id.equals(id))).write(companion);
        await _enqueue(
          existing.ledgerId,
          'transactions',
          id,
          'upsert',
          existing.version,
          now,
        );
      });

  Future<void> deleteTransaction(String id) => db.transaction(() async {
    final existing = await transactionById(id);
    if (existing == null || existing.deletedAt != null) return;
    await _softDelete('transactions', existing.ledgerId, id, existing.version);
  });

  /// 같은 날짜 · 금액 · 상대방의 거래. 저장 전에 중복을 알리는 데 쓴다.
  Future<List<TxRow>> findPossibleDuplicates(
    String ledgerId, {
    required LocalDate date,
    required int amount,
    String? counterparty,
  }) {
    final key = dedupKeyFor(date, amount, counterparty);
    final t = db.ledgerTransactions;
    return (db.select(t)..where(
          (x) =>
              x.ledgerId.equals(ledgerId) &
              x.dedupKey.equals(key) &
              x.deletedAt.isNull(),
        ))
        .get();
  }

  /// 취소 문자의 원 거래 후보.
  ///
  /// 같은 금액 · 상대방의 취소되지 않은 지출 가운데 [onOrBefore] 이전 90일 안의 가장 최근
  /// 거래를 돌려준다. 가맹점 이름이 잘려 올 수 있어 앞부분 일치도 받아들인다.
  Future<TxRow?> findCancelTarget(
    String ledgerId, {
    required int amount,
    required LocalDate onOrBefore,
    String? counterparty,
  }) async {
    final t = db.ledgerTransactions;
    final candidates =
        await (db.select(t)
              ..where(
                (x) =>
                    x.ledgerId.equals(ledgerId) &
                    x.type.equalsValue(TxType.expense) &
                    x.amount.equals(amount) &
                    x.canceledAt.isNull() &
                    x.deletedAt.isNull() &
                    x.occurredOn.isSmallerOrEqualValue(onOrBefore.toString()) &
                    x.occurredOn.isBiggerOrEqualValue(
                      onOrBefore.addDays(-90).toString(),
                    ),
              )
              ..orderBy([
                (x) => OrderingTerm.desc(x.occurredOn),
                (x) => OrderingTerm.desc(x.id),
              ]))
            .get();
    final wanted = normalizeCounterparty(counterparty ?? '');
    for (final row in candidates) {
      final have = normalizeCounterparty(row.receiver ?? '');
      if (wanted.isEmpty || have.isEmpty) continue;
      if (have == wanted ||
          have.startsWith(wanted) ||
          wanted.startsWith(have)) {
        return row;
      }
    }
    return null;
  }

  /// 거래를 취소로 표시하거나 표시를 지운다. 취소된 거래는 집계에서 빠진다.
  Future<void> setCanceled(String id, {required bool canceled}) =>
      db.transaction(() async {
        final existing = await transactionById(id);
        if (existing == null || existing.deletedAt != null) {
          throw StateError('없는 거래입니다: $id');
        }
        final now = _now();
        await (db.update(
          db.ledgerTransactions,
        )..where((t) => t.id.equals(id))).write(
          LedgerTransactionsCompanion(
            canceledAt: Value(canceled ? now : null),
            clientUpdatedAt: Value(now),
          ),
        );
        await _enqueue(
          existing.ledgerId,
          'transactions',
          id,
          'upsert',
          existing.version,
          now,
        );
      });

  /// 중복 판별 키. 날짜 · 금액 · 상대방(공백과 대소문자를 무시)을 이어 붙인 값이다.
  static String dedupKeyFor(LocalDate date, int amount, String? counterparty) {
    final party = (counterparty ?? '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
    final clipped = party.length > 64 ? party.substring(0, 64) : party;
    return '$date|$amount|$clipped';
  }

  Future<LedgerTransactionsCompanion> _companionFor(
    String ledgerId,
    TransactionInput input,
    DateTime now,
  ) async {
    if (input.amount == 0) throw ArgumentError('금액이 0입니다');
    final account = await _accountOrThrow(ledgerId, input.accountId);

    AccountRow? toAccount;
    if (input.type == TxType.transfer) {
      final toId = input.toAccountId;
      if (toId == null) throw ArgumentError('이체에는 받는 자산이 필요합니다');
      if (toId == input.accountId) throw ArgumentError('같은 자산으로는 이체할 수 없습니다');
      toAccount = await _accountOrThrow(ledgerId, toId);
    }

    final counterparty = _blankToNull(input.counterparty);
    final (sender, receiver) = switch (input.type) {
      TxType.expense => (account.name, counterparty),
      TxType.income => (counterparty, account.name),
      TxType.transfer => (account.name, toAccount!.name),
    };

    return LedgerTransactionsCompanion(
      type: Value(input.type),
      occurredOn: Value(input.occurredOn),
      occurredTime: Value(_blankToNull(input.occurredTime)),
      amount: Value(input.amount),
      currency: Value(_blankToNull(input.currency)),
      originalAmount: Value(input.originalAmount),
      accountId: Value(input.accountId),
      toAccountId: Value(toAccount?.id),
      sender: Value(sender),
      receiver: Value(receiver),
      // 이체에는 분류를 두지 않는다.
      categoryId: Value(
        input.type == TxType.transfer ? null : input.categoryId,
      ),
      memo: Value(_blankToNull(input.memo)),
      installmentMonths: Value(input.installmentMonths),
      balanceAfter: Value(input.balanceAfter),
      canceledAt: Value(input.canceled ? now : null),
      source: Value(input.source),
      aiModel: Value(input.aiModel),
      status: Value(input.status),
      dedupKey: Value(
        dedupKeyFor(
          input.occurredOn,
          input.amount,
          input.type == TxType.transfer ? null : counterparty,
        ),
      ),
      clientUpdatedAt: Value(now),
    );
  }

  Future<AccountRow> _accountOrThrow(String ledgerId, String id) async {
    final account =
        await (db.select(db.accounts)..where(
              (a) =>
                  a.id.equals(id) &
                  a.ledgerId.equals(ledgerId) &
                  a.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (account == null) throw ArgumentError('없는 자산입니다: $id');
    return account;
  }

  // ------------------------------------------------------------------ 분류 규칙

  /// 상대방에 맞는 분류 규칙을 찾는다. 완전 일치를 먼저 보고, 없으면 앞부분 일치를 본다.
  ///
  /// 결제 문자의 가맹점 이름은 글자 수 제한으로 잘려 오므로('세븐일레븐영') 앞부분이
  /// 같은 규칙도 받아들인다.
  Future<String?> categoryForCounterparty(
    String ledgerId,
    String counterparty,
  ) async {
    final pattern = normalizeCounterparty(counterparty);
    if (pattern.isEmpty) return null;
    final r = db.categoryRules;
    final rules =
        await (db.select(r)
              ..where((x) => x.ledgerId.equals(ledgerId) & x.deletedAt.isNull())
              ..orderBy([(x) => OrderingTerm.desc(x.hitCount)]))
            .get();
    for (final rule in rules) {
      if (rule.pattern == pattern) return rule.categoryId;
    }
    for (final rule in rules) {
      final shorter = rule.pattern.length < pattern.length
          ? rule.pattern
          : pattern;
      final longer = identical(shorter, pattern) ? rule.pattern : pattern;
      if (shorter.length >= 4 && longer.startsWith(shorter)) {
        return rule.categoryId;
      }
    }
    return null;
  }

  /// 사용자가 고른 분류를 상대방의 규칙으로 기억한다.
  Future<void> rememberCategory(
    String ledgerId,
    String counterparty,
    String categoryId,
  ) => db.transaction(() async {
    final pattern = normalizeCounterparty(counterparty);
    if (pattern.isEmpty) return;
    final now = _now();
    final r = db.categoryRules;
    final existing =
        await (db.select(r)..where(
              (x) =>
                  x.ledgerId.equals(ledgerId) &
                  x.pattern.equals(pattern) &
                  x.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing == null) {
      final id = _newId();
      await db
          .into(r)
          .insert(
            CategoryRulesCompanion.insert(
              id: id,
              ledgerId: ledgerId,
              pattern: pattern,
              categoryId: categoryId,
              hitCount: const Value(1),
              clientUpdatedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _enqueue(ledgerId, 'category_rules', id, 'upsert', 0, now);
    } else {
      await (db.update(r)..where((x) => x.id.equals(existing.id))).write(
        CategoryRulesCompanion(
          categoryId: Value(categoryId),
          hitCount: Value(existing.hitCount + 1),
          clientUpdatedAt: Value(now),
        ),
      );
      await _enqueue(
        ledgerId,
        'category_rules',
        existing.id,
        'upsert',
        existing.version,
        now,
      );
    }
  });

  /// 분류 규칙의 키. 공백과 대소문자를 무시한다.
  static String normalizeCounterparty(String text) =>
      text.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  // ------------------------------------------------------------------ 집계

  /// 한 달 집계. 거래가 바뀌면 다시 계산해 흘려보낸다.
  Stream<MonthSummary> watchMonthSummary(
    String ledgerId,
    MonthPeriod period, {
    required LocalDate today,
  }) {
    final trigger = db.customSelect(
      'SELECT COUNT(*) AS n FROM transactions',
      readsFrom: {db.ledgerTransactions, db.categories},
    );
    return trigger.watch().asyncMap(
      (_) => monthSummary(ledgerId, period, today: today),
    );
  }

  Future<MonthSummary> monthSummary(
    String ledgerId,
    MonthPeriod period, {
    required LocalDate today,
  }) async {
    const scope = '''
      ledger_id = ?1 AND occurred_on >= ?2 AND occurred_on < ?3
      AND deleted_at IS NULL AND canceled_at IS NULL
    ''';
    List<Variable> vars(MonthPeriod p) => [
      Variable.withString(ledgerId),
      Variable.withString(p.start.toString()),
      Variable.withString(p.endExclusive.toString()),
    ];

    Future<({int income, int expense, int count})> totals(MonthPeriod p) async {
      final rows = await db.customSelect('''
            SELECT type, COALESCE(SUM(amount), 0) AS total, COUNT(*) AS n
            FROM transactions
            WHERE $scope AND type <> 'transfer'
            GROUP BY type
            ''', variables: vars(p)).get();
      var income = 0, expense = 0, count = 0;
      for (final row in rows) {
        final total = row.read<int>('total');
        count += row.read<int>('n');
        if (row.read<String>('type') == TxType.income.code) {
          income = total;
        } else {
          expense = total;
        }
      }
      return (income: income, expense: expense, count: count);
    }

    final current = await totals(period);
    final previous = await totals(period.previous);

    final categoryRows = await db.customSelect('''
          SELECT t.category_id AS category_id, c.name AS name, SUM(t.amount) AS total
          FROM transactions t
          LEFT JOIN categories c ON c.id = t.category_id
          WHERE t.ledger_id = ?1 AND t.occurred_on >= ?2 AND t.occurred_on < ?3
            AND t.deleted_at IS NULL AND t.canceled_at IS NULL AND t.type = 'expense'
          GROUP BY t.category_id
          ORDER BY total DESC
          ''', variables: vars(period)).get();

    final partyRows = await db.customSelect('''
          SELECT receiver AS name, SUM(amount) AS total, COUNT(*) AS n
          FROM transactions
          WHERE $scope AND type = 'expense' AND receiver IS NOT NULL AND receiver <> ''
          GROUP BY receiver
          ORDER BY total DESC, n DESC
          LIMIT 5
          ''', variables: vars(period)).get();

    final largestRows = await db.customSelect('''
          SELECT id, occurred_on, amount,
                 COALESCE(NULLIF(receiver, ''), NULLIF(memo, ''), '') AS name
          FROM transactions
          WHERE $scope AND type = 'expense'
          ORDER BY amount DESC, occurred_on DESC
          LIMIT 5
          ''', variables: vars(period)).get();

    final dailyRows = await db.customSelect('''
          SELECT occurred_on, SUM(amount) AS total
          FROM transactions
          WHERE $scope AND type = 'expense'
          GROUP BY occurred_on
          ''', variables: vars(period)).get();
    final daily = {
      for (final row in dailyRows)
        LocalDate.parse(row.read<String>('occurred_on')): row.read<int>(
          'total',
        ),
    };

    // 오늘까지 지난 날 수와 그 가운데 지출이 없던 날 수
    final int elapsed;
    if (today < period.start) {
      elapsed = 0;
    } else if (today >= period.last) {
      elapsed = period.days;
    } else {
      elapsed = today.differenceInDays(period.start) + 1;
    }
    var spendDays = 0;
    for (final entry in daily.entries) {
      if (entry.value > 0 && entry.key <= today) spendDays++;
    }

    return MonthSummary(
      period: period,
      income: current.income,
      expense: current.expense,
      previousIncome: previous.income,
      previousExpense: previous.expense,
      transactionCount: current.count,
      byCategory: [
        for (final row in categoryRows)
          CategoryTotal(
            categoryId: row.read<String?>('category_id'),
            name: row.read<String?>('name') ?? '분류 없음',
            amount: row.read<int>('total'),
          ),
      ],
      topCounterparties: [
        for (final row in partyRows)
          CounterpartyTotal(
            name: row.read<String>('name'),
            amount: row.read<int>('total'),
            count: row.read<int>('n'),
          ),
      ],
      largestExpenses: [
        for (final row in largestRows)
          LargeExpense(
            transactionId: row.read<String>('id'),
            date: LocalDate.parse(row.read<String>('occurred_on')),
            name: row.read<String>('name'),
            amount: row.read<int>('amount'),
          ),
      ],
      dailyExpense: daily,
      noSpendDays: elapsed - spendDays < 0 ? 0 : elapsed - spendDays,
      elapsedDays: elapsed,
    );
  }

  // ------------------------------------------------------------------ 대기열

  /// 아직 서버로 보내지 않은 변경 수.
  Stream<int> watchPendingChangeCount() {
    final count = db.outbox.seq.count();
    return (db.selectOnly(
      db.outbox,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<void> _enqueue(
    String ledgerId,
    String table,
    String rowId,
    String op,
    int baseVersion,
    DateTime at,
  ) => outbox.enqueue(ledgerId, table, rowId, op, baseVersion, at);

  Future<void> _softDelete(
    String table,
    String ledgerId,
    String rowId,
    int version,
  ) => outbox.softDelete(table, ledgerId, rowId, version);
}

String? _blankToNull(String? text) {
  final trimmed = text?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

String _escapeLike(String text) =>
    text.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
