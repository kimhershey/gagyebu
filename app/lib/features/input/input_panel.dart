import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/input_interpreter.dart';
import '../../ai/parsed_transaction.dart';
import '../../ai/text/paste_parser.dart';
import '../../app/providers.dart';
import '../../core/formatters.dart';
import '../../data/db/database.dart';
import '../../domain/enums.dart';
import '../common/widgets.dart';
import 'review_draft.dart';

/// AI 입력: 한 줄 문장이나 붙여넣은 결제 문자를 해석해 검토 카드로 보여 준다.
///
/// 해석 순서는 [interpretInput]에 있다. 아는 형식은 규칙이 바로 읽고, 규칙이 읽지 못한
/// 덩어리는 기기 안의 모델([llmEngineProvider])이 있으면 그쪽에 넘긴다. 어느 쪽이든
/// 사용자가 확인해야 저장된다.
class InputPanel extends ConsumerStatefulWidget {
  const InputPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<InputPanel> createState() => _InputPanelState();
}

class _InputPanelState extends ConsumerState<InputPanel> {
  final _text = TextEditingController();
  final _parser = PasteParser();

  List<ReviewDraft>? _drafts;
  List<NonTransactionItem> _notices = const [];
  List<UnrecognizedItem> _unknown = const [];
  TxSource _source = TxSource.paste;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('클립보드에 글자가 없습니다')));
      return;
    }
    _text.text = text;
    await _analyze();
  }

  Future<void> _analyze() async {
    final input = _text.text;
    if (input.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final today = ref.read(todayProvider);
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(ledgerIdProvider);
      final accounts = await repo.accounts(ledgerId);
      final categories = await repo.categories(ledgerId);
      final profile = await repo.profile(ledgerId);

      final interpreted = await interpretInput(
        input,
        today: today,
        engine: ref.read(llmEngineProvider),
        parser: _parser,
        expenseCategories: [
          for (final c in categories)
            if (c.kind == CategoryKind.expense) c.name,
        ],
        incomeCategories: [
          for (final c in categories)
            if (c.kind == CategoryKind.income) c.name,
        ],
      );
      final items = interpreted.items;
      final source = interpreted.fromSentence ? TxSource.nl : TxSource.paste;

      final drafts = <ReviewDraft>[];
      for (final item in items.whereType<TransactionItem>()) {
        drafts.add(
          await buildReviewDraft(
            repository: repo,
            ledgerId: ledgerId,
            parsed: item.transaction,
            accounts: accounts,
            categories: categories,
            defaultAccountId: profile?.defaultAccountId,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _notices = items.whereType<NonTransactionItem>().toList();
        _unknown = items.whereType<UnrecognizedItem>().toList();
        _source = source;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final drafts = _drafts;
    if (drafts == null) return;
    setState(() => _busy = true);
    try {
      final saved = await saveReviewDrafts(
        repository: ref.read(repositoryProvider),
        ledgerId: ref.read(ledgerIdProvider),
        drafts: drafts,
        source: _source,
      );
      if (!mounted) return;
      final first = drafts.where((d) => d.canSave).firstOrNull;
      if (first != null) {
        ref.read(selectedPeriodProvider.notifier).show(first.date);
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$saved건을 저장했습니다')));
      widget.onClose();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drafts = _drafts;
    final accounts = ref.watch(accountsProvider).value ?? const <AccountRow>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryRow>[];
    final savable = drafts?.where((d) => d.canSave).length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text('입력', style: theme.textTheme.titleLarge)),
              IconButton(
                tooltip: '닫기',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              TextField(
                key: const ValueKey('input-text'),
                controller: _text,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      '한 줄로 적거나 결제 문자를 붙여넣으세요\n'
                      '예) 어제 점심 김밥천국 8천원 카드로',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _paste,
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: const Text('붙여넣기'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey('input-analyze'),
                    onPressed: _busy ? null : _analyze,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('해석'),
                  ),
                ],
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (drafts != null) ...[
                const SizedBox(height: 16),
                if (drafts.isEmpty && _unknown.isEmpty && _notices.isEmpty)
                  const EmptyState(
                    icon: Icons.help_outline,
                    message: '읽을 내용이 없습니다',
                  ),
                for (var i = 0; i < drafts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ReviewCard(
                      key: ValueKey('review-$i'),
                      draft: drafts[i],
                      accounts: accounts,
                      categories: categories,
                      currentYear: ref.watch(todayProvider).year,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                if (_notices.isNotEmpty)
                  _InfoBox(
                    key: const ValueKey('notices'),
                    icon: Icons.filter_alt_outlined,
                    title: '거래가 아닌 안내문 ${_notices.length}건은 뺐습니다',
                    lines: [for (final n in _notices) _oneLine(n.raw)],
                  ),
                if (_unknown.isNotEmpty)
                  _InfoBox(
                    key: const ValueKey('unknown'),
                    icon: Icons.help_outline,
                    title: '읽지 못한 내용 ${_unknown.length}건',
                    lines: [for (final u in _unknown) _oneLine(u.raw)],
                    footer: '아는 형식이 아닙니다. 내역 화면의 직접 입력으로 넣을 수 있습니다.',
                  ),
              ],
            ],
          ),
        ),
        if (drafts != null && drafts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              key: const ValueKey('input-save'),
              onPressed: (_busy || savable == 0) ? null : _save,
              child: Text(savable == 0 ? '저장할 거래가 없습니다' : '$savable건 저장'),
            ),
          ),
      ],
    );
  }
}

String _oneLine(String text) {
  final folded = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return folded.length > 80 ? '${folded.substring(0, 80)}…' : folded;
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    this.footer,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(line, style: muted),
            ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Text(footer!, style: muted),
          ],
        ],
      ),
    );
  }
}

/// 검토 카드. 읽어 낸 값을 보여 주고, 저장 전에 고치게 한다.
class ReviewCard extends StatefulWidget {
  const ReviewCard({
    super.key,
    required this.draft,
    required this.accounts,
    required this.categories,
    required this.currentYear,
    required this.onChanged,
  });

  final ReviewDraft draft;
  final List<AccountRow> accounts;
  final List<CategoryRow> categories;

  /// 올해. 연도를 올해가 아닌 해로 채웠을 때만 알린다.
  final int currentYear;
  final VoidCallback onChanged;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  late final _party = TextEditingController(text: widget.draft.counterparty);
  late final _amount = TextEditingController(
    text: widget.draft.amount == null ? '' : formatNumber(widget.draft.amount!),
  );

  @override
  void dispose() {
    _party.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final draft = widget.draft;
    final parsed = draft.parsed;
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

    final notes = <(IconData, String, bool)>[
      if (parsed.isCancel && draft.cancelTarget != null)
        (
          Icons.undo,
          '취소 문자입니다. 저장하면 ${monthDay(draft.cancelTarget!.occurredOn)} '
              '${draft.cancelTarget!.receiver ?? ''} ${won(draft.cancelTarget!.amount)} '
              '거래를 취소로 표시합니다',
          false,
        ),
      if (parsed.isCancel && draft.cancelTarget == null)
        (Icons.undo, '취소 문자입니다. 원 거래를 찾지 못해 환불(음수)로 적습니다', true),
      if (draft.duplicates > 0)
        (Icons.copy_all_outlined, '같은 날짜 · 금액 · 상대방의 거래가 이미 있습니다', true),
      if (parsed.warnings.contains(ParseWarning.needsKrwAmount))
        (
          Icons.currency_exchange,
          '해외 결제 ${parsed.originalAmount} ${parsed.currency}. 원화 금액을 넣어야 저장됩니다',
          true,
        ),
      if (parsed.warnings.contains(ParseWarning.possibleCardPayment))
        (Icons.credit_card, '카드대금 출금으로 보입니다. 카드 사용분과 두 번 세지 않게 확인하세요', true),
      // 대부분의 문자는 연도가 없다. 올해로 채운 흔한 경우는 알리지 않고,
      // 지난해로 넘어간 경우(1월에 붙여넣은 12월 문자)만 알린다.
      if (parsed.warnings.contains(ParseWarning.yearInferred) &&
          draft.date.year != widget.currentYear)
        (Icons.event, '연도가 없어 ${draft.date.year}년으로 채웠습니다', true),
      if (parsed.warnings.contains(ParseWarning.dateFromNow))
        (Icons.event, '날짜가 없어 오늘로 채웠습니다', false),
      if (parsed.warnings.contains(ParseWarning.amountWithoutUnit))
        (Icons.payments_outlined, '금액에 ‘원’이 없었습니다. 숫자를 확인하세요', false),
      if (!draft.accountMatched && parsed.accountText != null)
        (
          Icons.account_balance_wallet_outlined,
          '‘${parsed.accountText}’에 맞는 자산이 없어 기본 자산을 골랐습니다',
          false,
        ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: draft.include,
                  onChanged: (value) {
                    setState(() => draft.include = value ?? false);
                    widget.onChanged();
                  },
                ),
                Expanded(
                  child: Text(
                    '${dayLabel(draft.date)}'
                    '${parsed.time == null ? '' : ' ${parsed.time}'}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                SegmentedButton<TxType>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: TxType.expense, label: Text('지출')),
                    ButtonSegment(value: TxType.income, label: Text('수입')),
                  ],
                  selected: {
                    draft.type == TxType.income
                        ? TxType.income
                        : TxType.expense,
                  },
                  onSelectionChanged: (selection) {
                    setState(() {
                      draft.type = selection.first;
                      draft.categoryId = null;
                    });
                    widget.onChanged();
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _party,
                          decoration: InputDecoration(
                            labelText: draft.type == TxType.income
                                ? '보낸 사람 · 기관'
                                : '받는 사람 · 가맹점',
                          ),
                          onChanged: (value) => draft.counterparty = value,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: const ValueKey('review-amount'),
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          decoration: const InputDecoration(
                            labelText: '금액',
                            suffixText: '원',
                          ),
                          onChanged: (value) {
                            setState(
                              () => draft.amount = parseAmountInput(value),
                            );
                            widget.onChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              widget.accounts.any(
                                (a) => a.id == draft.accountId,
                              )
                              ? draft.accountId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: '자산'),
                          items: [
                            for (final a in widget.accounts)
                              DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => draft.accountId = value);
                            widget.onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          key: ValueKey('cat-${draft.type}'),
                          initialValue: categoryValue,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: '분류'),
                          items: [
                            const DropdownMenuItem<String?>(
                              child: Text('분류 없음'),
                            ),
                            for (final c in categoryOptions)
                              DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => draft.categoryId = value),
                        ),
                      ),
                    ],
                  ),
                  for (final (icon, text, strong) in notes)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: strong
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              text,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: strong
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (parsed.institution != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      [
                        parsed.accountText ?? parsed.institution!,
                        if (parsed.installmentMonths != null)
                          '${parsed.installmentMonths}개월 할부',
                        if (parsed.balanceAfter != null)
                          '잔액 ${won(parsed.balanceAfter!)}',
                        if (parsed.memo != null) parsed.memo!,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ] else if (parsed.memo != null) ...[
                    // 문장에서 덜어 낸 말('점심', '2잔')은 메모로 저장된다.
                    const SizedBox(height: 8),
                    Text(
                      '메모: ${parsed.memo}',
                      key: const Key('draft-memo'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
