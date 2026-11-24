import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/card_due.dart';
import '../../domain/enums.dart';

/// 자산 화면의 한 줄.
class AccountItem {
  const AccountItem({
    required this.account,
    required this.balance,
    this.due,
    this.paymentAccountName,
  });

  final AccountRow account;

  /// 보여 줄 잔액. 연결 계좌가 있는 체크카드는 따로 세지 않아 null이다.
  final int? balance;

  /// 신용카드의 다음 결제일과 예정액. 결제일을 정하지 않았으면 null.
  final CardDue? due;

  /// 결제 계좌(신용카드) · 연결 계좌(체크카드)의 이름.
  final String? paymentAccountName;
}

/// 같은 종류의 자산 묶음.
class AccountSection {
  const AccountSection({required this.kind, required this.items});

  final AccountKind kind;
  final List<AccountItem> items;
}

/// 자산을 종류별로 묶고 줄마다 보여 줄 값을 붙인다(`docs/SPEC.md` 7.2 · 7.12).
///
/// 체크카드는 연결 계좌에서 바로 나간 것으로 본다: 체크카드로 쓴 돈을 연결 계좌의 잔액에
/// 합치고 카드의 잔액은 따로 보이지 않는다. 연결 계좌가 없으면 카드의 잔액을 그대로 보인다.
///
/// [spends]는 결제 예정을 셀 지출이다. 아직 읽지 못했으면 null을 주고, 그러면 결제 예정을
/// 붙이지 않는다(0원으로 잘못 보이지 않게).
List<AccountSection> buildAccountSections(
  List<AccountBalance> balances, {
  required Iterable<CardSpend>? spends,
  required LocalDate today,
}) {
  final byId = {for (final b in balances) b.account.id: b};

  /// 체크카드의 돈이 실제로 드나드는 계좌. 없거나 지워졌으면 null.
  AccountRow? linkedOf(AccountRow account) {
    if (account.kind != AccountKind.checkCard) return null;
    final linked = byId[account.paymentAccountId]?.account;
    // 체크카드끼리 물려 있으면 합칠 곳이 없다.
    if (linked == null || linked.kind == AccountKind.checkCard) return null;
    return linked;
  }

  final shown = {for (final b in balances) b.account.id: b.balance};
  for (final b in balances) {
    final linked = linkedOf(b.account);
    if (linked == null) continue;
    shown[linked.id] = shown[linked.id]! + b.balance;
  }

  return [
    for (final kind in AccountKind.values)
      if (balances.any((b) => b.account.kind == kind))
        AccountSection(
          kind: kind,
          items: [
            for (final b in balances)
              if (b.account.kind == kind)
                AccountItem(
                  account: b.account,
                  balance: linkedOf(b.account) == null
                      ? shown[b.account.id]
                      : null,
                  due:
                      kind == AccountKind.creditCard &&
                          b.account.billingDay != null &&
                          spends != null
                      ? cardDue(
                          CardAccount(
                            id: b.account.id,
                            billingDay: b.account.billingDay!,
                          ),
                          spends,
                          today,
                        )
                      : null,
                  paymentAccountName: switch (kind) {
                    AccountKind.creditCard || AccountKind.checkCard =>
                      byId[b.account.paymentAccountId]?.account.name,
                    _ => null,
                  },
                ),
          ],
        ),
  ];
}

/// 카드의 결제 예정을 세는 데 쓰는 지출. 지난 결제일 다음 날부터 다음 결제일까지를 덮는
/// 넉넉한 범위(두 달 전부터 한 달 뒤까지)만 읽는다.
final cardSpendsProvider = StreamProvider<List<CardSpend>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(repositoryProvider)
      .watchTransactions(
        ref.watch(ledgerIdProvider),
        from: today.addDays(-62),
        toExclusive: today.addDays(32),
      )
      .map(
        (rows) => [
          for (final view in rows)
            CardSpend(
              accountId: view.row.accountId,
              type: view.row.type,
              date: view.row.occurredOn,
              amount: view.row.amount,
              canceled: view.isCanceled,
            ),
        ],
      );
});

/// 자산 화면에 그릴 묶음.
final accountSectionsProvider = Provider<AsyncValue<List<AccountSection>>>((
  ref,
) {
  final balances = ref.watch(accountBalancesProvider);
  final spends = ref.watch(cardSpendsProvider);
  final today = ref.watch(todayProvider);
  return balances.whenData(
    (list) => buildAccountSections(
      list,
      // 결제 예정은 덧붙이는 값이다. 아직 못 읽었으면 빼고 목록부터 그린다.
      spends: spends.value,
      today: today,
    ),
  );
});
