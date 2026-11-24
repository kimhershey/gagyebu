import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/parsed_transaction.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../data/db/database.dart';
import '../../domain/enums.dart';
import 'review_state.dart';

/// 검토함의 한 건: 한 줄 요약(날짜 · 상대방 · 금액 · 분류)과, 펼치면 나오는 편집 칸.
class ReviewTile extends ConsumerStatefulWidget {
  const ReviewTile({
    super.key,
    required this.index,
    required this.draft,
    required this.accounts,
    required this.categories,
    required this.today,
    required this.expanded,
    required this.highlighted,
    required this.onFocus,
  });

  final int index;
  final ReviewDraft draft;
  final List<AccountRow> accounts;
  final List<CategoryRow> categories;
  final LocalDate today;

  /// 편집 칸을 펼쳤는지.
  final bool expanded;

  /// 키보드로 고른 건인지.
  final bool highlighted;

  /// 이 건을 눌렀을 때. 검토함이 초점을 가져가 키보드로 이어서 다루게 한다.
  final VoidCallback onFocus;

  @override
  ConsumerState<ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends ConsumerState<ReviewTile> {
  @override
  void didUpdateWidget(ReviewTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 키보드로 옮겨 온 건이 화면 밖이면 보이게 당긴다.
    if (widget.highlighted && !oldWidget.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        Scrollable.ensureVisible(
          context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      });
    }
  }

  String? _accountName(String? id) {
    for (final a in widget.accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final draft = widget.draft;
    final index = widget.index;
    final parsed = draft.parsed;
    final session = ref.read(reviewSessionProvider.notifier);
    final transfer = draft.type == TxType.transfer;

    String? categoryName;
    for (final c in widget.categories) {
      if (c.id == draft.categoryId) categoryName = c.name;
    }
    final accountName = _accountName(draft.accountId);
    final party = draft.counterparty.trim();

    final title = draft.cancelsExisting
        ? '취소: ${party.isEmpty ? '원 거래' : party}'
        : transfer
        ? '${accountName ?? '자산 없음'} → '
              '${_accountName(draft.toAccountId) ?? '받는 자산 없음'}'
        : party.isEmpty
        ? '(상대방 없음)'
        : party;
    final subtitle = [
      '${dayLabel(draft.date)}${parsed.time == null ? '' : ' ${parsed.time}'}',
      if (draft.cancelsExisting)
        '원 거래를 취소로 표시'
      else if (transfer)
        '이체'
      else ...[
        categoryName ?? '분류 없음',
        ?accountName,
      ],
    ].join(' · ');

    final (amountText, amountColor) = _amountLabel(draft, tokens);
    final dim = draft.include ? 1.0 : 0.5;

    final tags = <Widget>[
      if (draft.include && draft.needsReview)
        _Tag(
          '확인 필요',
          key: ValueKey('review-flag-$index'),
          color: tokens.warn,
          background: tokens.warnSoft,
        ),
      if (draft.blocksSave)
        _Tag(draft.missing!, color: tokens.warn, background: tokens.warnSoft),
      if (draft.duplicates > 0)
        _Tag(
          draft.include ? '중복일 수 있음' : '중복이라 제외',
          key: ValueKey('review-duplicate-$index'),
          color: scheme.onSurfaceVariant,
          background: scheme.surfaceContainerHighest,
        )
      else if (!draft.include)
        _Tag(
          '제외',
          color: scheme.onSurfaceVariant,
          background: scheme.surfaceContainerHighest,
        ),
      if (draft.transferSuggested && transfer)
        _Tag(
          '이체로 제안',
          color: scheme.onSurfaceVariant,
          background: scheme.surfaceContainerHighest,
        ),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      color: widget.highlighted ? tokens.accentSoft : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Tooltip(
                  message: draft.include ? '포함 · 누르면 제외합니다' : '제외 · 누르면 포함합니다',
                  child: Checkbox(
                    key: ValueKey('review-include-$index'),
                    value: draft.include,
                    onChanged: (value) =>
                        session.setInclude(index, value ?? false),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  key: ValueKey('review-row-$index'),
                  onTap: () {
                    widget.onFocus();
                    session.toggleExpanded(index);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Opacity(
                      opacity: dim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  key: ValueKey('review-title-$index'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 글자를 키워도 금액이 잘리지 않게, 넘치면 줄여서 다 보인다.
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 150,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    amountText,
                                    key: ValueKey('review-amount-label-$index'),
                                    maxLines: 1,
                                    style: tokens
                                        .amountStyle(theme.textTheme.bodyLarge)
                                        .copyWith(
                                          color: amountColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            key: ValueKey('review-subtitle-$index'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 4, children: tags),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('review-edit-$index'),
                tooltip: widget.expanded ? '접기' : '고치기',
                onPressed: () {
                  widget.onFocus();
                  session.toggleExpanded(index);
                },
                icon: Icon(
                  widget.expanded ? Icons.expand_less : Icons.edit_outlined,
                ),
              ),
            ],
          ),
          if (widget.expanded)
            _DraftEditor(
              index: index,
              draft: draft,
              accounts: widget.accounts,
              categories: widget.categories,
              today: widget.today,
            ),
        ],
      ),
    );
  }
}

/// 금액을 종류에 맞는 부호와 색으로. 이체에는 부호를 붙이지 않는다.
(String, Color) _amountLabel(ReviewDraft draft, AppTokens tokens) {
  final amount = draft.amount;
  if (amount == null) return ('금액 없음', tokens.warn);
  if (draft.cancelsExisting) return ('${won(amount)} 취소', tokens.transfer);
  // 원 거래를 찾지 못한 취소는 환불로 적는다. 나간 돈이 돌아온 것이다.
  final refund = draft.parsed.isCancel;
  return switch (draft.type) {
    TxType.income => ('+${won(amount)}', tokens.income),
    TxType.expense => ('${refund ? '+' : '-'}${won(amount)}', tokens.expense),
    TxType.transfer => (won(amount), tokens.transfer),
  };
}

/// 건에 붙는 짧은 표시('확인 필요', '중복').
class _Tag extends StatelessWidget {
  const _Tag(
    this.label, {
    super.key,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(context.tokens.radius / 2),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

/// 이 건에서 사용자가 알아야 할 점. (아이콘, 문장, 눈에 띄게 할지)
List<(IconData, String, bool)> _notesFor(ReviewDraft draft) {
  final parsed = draft.parsed;
  final warnings = draft.warnings;
  final target = draft.cancelTarget;
  return [
    if (parsed.isCancel && target != null)
      (
        Icons.undo,
        '취소 문자입니다. 저장하면 ${monthDay(target.occurredOn)} '
            '${target.receiver ?? ''} ${won(target.amount)} 거래를 취소로 표시합니다.',
        false,
      ),
    if (parsed.isCancel && target == null)
      (Icons.undo, '취소 문자입니다. 원 거래를 찾지 못해 환불로 적습니다.', true),
    if (draft.duplicates > 0)
      (
        Icons.copy_all_outlined,
        '날짜 · 금액 · 상대방이 같은 거래가 이미 있어 제외해 두었습니다. 다른 거래라면 포함해 주세요.',
        true,
      ),
    if (warnings.contains(ParseWarning.needsKrwAmount))
      (
        Icons.currency_exchange,
        '해외 결제 ${parsed.originalAmount} ${parsed.currency}입니다. '
            '원화 금액을 넣어야 저장됩니다.',
        true,
      ),
    if (draft.transferSuggested)
      (Icons.swap_horiz, '카드대금 출금으로 보여 이체(계좌 → 카드)로 제안했습니다. 맞는지 확인해 주세요.', true)
    else if (warnings.contains(ParseWarning.possibleCardPayment))
      (
        Icons.credit_card,
        '카드대금 출금으로 보입니다. 카드로 쓴 돈과 두 번 세지 않게 이체로 바꿔 주세요.',
        true,
      ),
    if (warnings.contains(ParseWarning.yearInferred))
      (Icons.event, '연도가 없어 ${parsed.date.year}년으로 채웠습니다.', true),
    if (warnings.contains(ParseWarning.dateFromNow))
      (Icons.event, '날짜가 없어 오늘로 채웠습니다.', true),
    if (warnings.contains(ParseWarning.amountWithoutUnit))
      (Icons.payments_outlined, '금액에 ‘원’이 없었습니다. 숫자를 확인해 주세요.', true),
    if (warnings.contains(ParseWarning.noCounterparty))
      (Icons.storefront_outlined, '상대방을 찾지 못했습니다. 어디에 쓴 돈인지 적어 주세요.', true),
    if (warnings.contains(ParseWarning.directionMismatch))
      (Icons.swap_vert, '수입 · 지출이 원문의 낱말과 어긋납니다. 종류를 확인해 주세요.', true),
    if (!draft.accountMatched && parsed.accountText != null)
      (
        Icons.account_balance_wallet_outlined,
        '‘${parsed.accountText}’에 맞는 자산이 없어 기본 자산을 골랐습니다.',
        false,
      ),
  ];
}

/// 펼친 건의 편집 칸: 종류, 금액, 날짜, 자산, (이체면 받는 자산 / 아니면 상대방과 분류), 메모.
class _DraftEditor extends ConsumerStatefulWidget {
  const _DraftEditor({
    required this.index,
    required this.draft,
    required this.accounts,
    required this.categories,
    required this.today,
  });

  final int index;
  final ReviewDraft draft;
  final List<AccountRow> accounts;
  final List<CategoryRow> categories;
  final LocalDate today;

  @override
  ConsumerState<_DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends ConsumerState<_DraftEditor> {
  late final _party = TextEditingController(text: widget.draft.counterparty);
  late final _amount = TextEditingController(
    text: widget.draft.amount == null ? '' : formatNumber(widget.draft.amount!),
  );
  late final _memo = TextEditingController(text: widget.draft.memo ?? '');

  ReviewSession get _session => ref.read(reviewSessionProvider.notifier);

  @override
  void dispose() {
    _party.dispose();
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _edit(ReviewDraft Function(ReviewDraft draft) change) =>
      _session.edit(widget.index, change);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.draft.date.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: widget.today.addDays(366).toDateTime(),
    );
    if (picked != null) {
      _edit((d) => d.copyWith(date: LocalDate.fromDateTime(picked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final draft = widget.draft;
    final index = widget.index;
    final parsed = draft.parsed;
    final accounts = widget.accounts;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final notes = _notesFor(draft);
    final noteLines = [
      for (final (icon, text, strong) in notes)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 16,
                color: strong ? tokens.warn : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: strong ? tokens.warn : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];

    // 원 거래를 취소로 표시하는 건은 고칠 값이 없다. 포함할지만 정한다.
    if (draft.cancelsExisting) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: noteLines,
        ),
      );
    }

    final kind = draft.type == TxType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final categoryOptions = [
      for (final c in widget.categories)
        if (c.kind == kind) c,
    ];
    final categoryValue = categoryOptions.any((c) => c.id == draft.categoryId)
        ? draft.categoryId
        : null;
    final accountValue = accounts.any((a) => a.id == draft.accountId)
        ? draft.accountId
        : null;
    final toAccountValue = accounts.any((a) => a.id == draft.toAccountId)
        ? draft.toAccountId
        : null;
    final transfer = draft.type == TxType.transfer;

    Widget typeChip(TxType type, String label) => ChoiceChip(
      key: ValueKey('review-type-${type.code}-$index'),
      label: Text(label),
      selected: draft.type == type,
      onSelected: (_) {
        if (draft.type == type) return;
        _edit(
          (d) => d.copyWith(
            type: type,
            // 지출과 수입은 분류가 따로다. 이체에는 분류가 없다.
            categoryId: null,
            toAccountId: type == TxType.transfer ? d.toAccountId : null,
          ),
        );
      },
    );

    const gap = SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...noteLines,
          if (draft.needsReview)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: ValueKey('review-confirm-$index'),
                onPressed: () => _session.confirm(index),
                child: const Text('맞습니다 · 확인함'),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              typeChip(TxType.expense, '지출'),
              typeChip(TxType.income, '수입'),
              typeChip(TxType.transfer, '이체'),
            ],
          ),
          gap,
          TextField(
            key: ValueKey('review-amount-$index'),
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '금액', suffixText: '원'),
            onChanged: (value) =>
                _edit((d) => d.copyWith(amount: parseAmountInput(value))),
          ),
          gap,
          InkWell(
            key: ValueKey('review-date-$index'),
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '날짜'),
              child: Text(
                '${fullDateLabel(draft.date)}'
                '${parsed.time == null ? '' : ' ${parsed.time}'}',
              ),
            ),
          ),
          gap,
          KeyedSubtree(
            key: ValueKey('review-account-$index'),
            child: DropdownButtonFormField<String>(
              // 값이 밖에서 바뀌면(이체 제안 등) 새 값으로 다시 그린다.
              key: ValueKey('account-$accountValue'),
              initialValue: accountValue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: transfer ? '보내는 자산' : '자산',
              ),
              items: [
                for (final a in accounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              onChanged: (value) => _edit((d) => d.copyWith(accountId: value)),
            ),
          ),
          gap,
          if (transfer)
            KeyedSubtree(
              key: ValueKey('review-to-account-$index'),
              child: DropdownButtonFormField<String>(
                key: ValueKey('to-account-$toAccountValue'),
                initialValue: toAccountValue,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '받는 자산'),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (value) =>
                    _edit((d) => d.copyWith(toAccountId: value)),
              ),
            )
          else ...[
            TextField(
              key: ValueKey('review-party-$index'),
              controller: _party,
              decoration: InputDecoration(
                labelText: draft.type == TxType.income
                    ? '보낸 사람 · 기관'
                    : '받는 사람 · 가맹점',
              ),
              onChanged: (value) =>
                  _edit((d) => d.copyWith(counterparty: value)),
            ),
            gap,
            KeyedSubtree(
              key: ValueKey('review-category-$index'),
              child: DropdownButtonFormField<String?>(
                key: ValueKey('category-${draft.type.code}-$categoryValue'),
                initialValue: categoryValue,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '분류'),
                items: [
                  const DropdownMenuItem<String?>(child: Text('분류 없음')),
                  for (final c in categoryOptions)
                    DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (value) =>
                    _edit((d) => d.copyWith(categoryId: value)),
              ),
            ),
          ],
          gap,
          TextField(
            key: ValueKey('review-memo-$index'),
            controller: _memo,
            decoration: const InputDecoration(labelText: '메모'),
            onChanged: (value) =>
                _edit((d) => d.copyWith(memo: value.isEmpty ? null : value)),
          ),
          if (parsed.institution != null ||
              parsed.installmentMonths != null ||
              parsed.balanceAfter != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                ?(parsed.accountText ?? parsed.institution),
                if (parsed.installmentMonths != null)
                  '${parsed.installmentMonths}개월 할부',
                if (parsed.balanceAfter != null)
                  '잔액 ${won(parsed.balanceAfter!)}',
              ].join(' · '),
              style: muted,
            ),
          ],
        ],
      ),
    );
  }
}

/// 접어 둔 칸: 거래가 아닌 안내문, 읽지 못한 글. 누르면 원문의 앞부분이 보인다.
class FoldedSection extends StatelessWidget {
  const FoldedSection({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    this.footer,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final String? footer;

  /// 줄마다 붙는 단추의 이름. 없으면 단추가 없다.
  final String? actionLabel;

  /// 단추의 키 앞머리. 뒤에 줄 번호가 붙는다.
  final String? actionKey;
  final void Function(int index)? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, size: 20),
        title: Text(title, style: theme.textTheme.titleSmall),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(_oneLine(lines[i]), style: muted)),
                  if (actionLabel != null)
                    TextButton(
                      key: actionKey == null ? null : ValueKey('$actionKey-$i'),
                      onPressed: () => onAction?.call(i),
                      child: Text(actionLabel!),
                    ),
                ],
              ),
            ),
          if (footer != null) Text(footer!, style: muted),
        ],
      ),
    );
  }
}

/// 원문을 한 줄로 접고 길면 자른다.
String _oneLine(String text) {
  final folded = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return folded.length > 80 ? '${folded.substring(0, 80)}…' : folded;
}
