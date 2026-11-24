import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../ai/parsed_transaction.dart';
import '../../ai/vision/vision_rows.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';

/// "확인 필요"의 까닭을 화면의 문장으로 옮긴다.
String visionIssueMessage(VisionIssue issue, VisionCheck check) {
  final expected = check.expected;
  final actual = check.actual;
  return switch (issue) {
    VisionIssue.balanceBreak when expected != null && actual != null =>
      '잔액이 이어지지 않습니다. 앞 줄의 잔액으로 셈하면 ${won(expected)}인데 '
          '${won(actual)}으로 읽었습니다. 금액을 원본과 견주어 주세요.',
    VisionIssue.balanceBreak => '잔액이 이어지지 않습니다. 금액을 원본과 견주어 주세요.',
    VisionIssue.directionReversed => '입금 · 출금이 잔액과 반대입니다. 수입인지 지출인지 확인해 주세요.',
    VisionIssue.sumMismatch when expected != null && actual != null =>
      '품목의 합(${won(expected)})이 금액(${won(actual)})과 다릅니다. '
          '원본의 합계와 견주어 주세요.',
    VisionIssue.sumMismatch => '품목의 합이 금액과 다릅니다. 원본의 합계와 견주어 주세요.',
    VisionIssue.totalMissing => '합계를 읽지 못해 품목의 합을 넣었습니다. 원본의 합계와 견주어 주세요.',
    VisionIssue.amountMissing => '금액을 읽지 못했습니다. 금액을 넣어 주세요.',
    VisionIssue.dateMissing => '날짜를 읽지 못해 짐작한 날짜를 넣었습니다. 날짜를 확인해 주세요.',
  };
}

/// 이미지에서 읽은 한 줄: 포함 여부, 한 줄 요약, 펼치면 나오는 고치는 칸.
///
/// 검산에 실패한 줄은 경고색 바탕에 까닭을 적는다. 값을 고치면 검산을 다시 하고,
/// 원본과 견주어 맞으면 "맞음"으로 표시를 푼다.
class ImageRowTile extends StatefulWidget {
  const ImageRowTile({
    super.key,
    required this.index,
    required this.row,
    required this.check,
    required this.issues,
    required this.included,
    required this.today,
    required this.onInclude,
    required this.onEdit,
    required this.onConfirm,
  });

  final int index;
  final VisionRow row;
  final VisionCheck check;

  /// 아직 풀리지 않은 까닭. 비어 있으면 "확인 필요"가 아니다.
  final Set<VisionIssue> issues;
  final bool included;
  final LocalDate today;
  final ValueChanged<bool> onInclude;
  final void Function(VisionRow Function(VisionRow row) change) onEdit;
  final VoidCallback onConfirm;

  @override
  State<ImageRowTile> createState() => _ImageRowTileState();
}

class _ImageRowTileState extends State<ImageRowTile> {
  late final TextEditingController _amount;
  late final TextEditingController _who;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: _amountText(widget.row.amount));
    _who = TextEditingController(text: widget.row.counterparty);
  }

  @override
  void didUpdateWidget(ImageRowTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다시 읽어 값이 바뀌었으면 칸도 따라간다. 치는 중에는 칸의 값이 곧 줄의 값이라
    // 건드리지 않는다.
    if (parseAmountInput(_amount.text) != widget.row.amount) {
      _amount.text = _amountText(widget.row.amount);
    }
    if (_who.text != widget.row.counterparty) {
      _who.text = widget.row.counterparty;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _who.dispose();
    super.dispose();
  }

  static String _amountText(int? amount) => amount == null ? '' : '$amount';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.row.date.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: widget.today.addDays(366).toDateTime(),
    );
    if (picked != null) {
      widget.onEdit((r) => r.copyWith(date: LocalDate.fromDateTime(picked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.tokens;
    final row = widget.row;
    final i = widget.index;
    final flagged = widget.included && widget.issues.isNotEmpty;
    final incoming = row.direction == Direction.incoming;
    final amount = row.amount;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final summary = Row(
      children: [
        Checkbox(
          key: ValueKey('image-row-include-$i'),
          semanticLabel: '포함',
          value: widget.included,
          onChanged: (value) => widget.onInclude(value ?? false),
        ),
        Text(
          '${row.date.month}.${row.date.day.toString().padLeft(2, '0')}',
          style: tokens.amountStyle(muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            row.counterparty.isEmpty ? '(상대방 없음)' : row.counterparty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: row.counterparty.isEmpty
                ? muted
                : theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        // 자릿수가 많은 금액은 줄여서라도 한 줄에 넣는다(좁은 창에서 넘치지 않게).
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              amount == null
                  ? '금액 없음'
                  : '${incoming ? '+' : '-'}${won(amount)}',
              key: ValueKey('image-row-amount-text-$i'),
              maxLines: 1,
              style: tokens
                  .amountStyle(theme.textTheme.bodyMedium)
                  .copyWith(
                    color: amount == null
                        ? tokens.warn
                        : (incoming ? tokens.income : tokens.expense),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        if (flagged)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: '확인 필요',
              child: Icon(
                Icons.warning_amber_rounded,
                key: ValueKey('image-row-flag-$i'),
                size: 18,
                color: tokens.warn,
              ),
            ),
          )
        else if (widget.check.verified)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: '검산이 맞습니다',
              child: Icon(
                Icons.check_circle_outline,
                key: ValueKey('image-row-verified-$i'),
                size: 18,
                color: tokens.ok,
              ),
            ),
          ),
        IconButton(
          key: ValueKey('image-row-edit-$i'),
          tooltip: _open ? '접기' : '고치기',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.expand_less : Icons.edit_outlined, size: 20),
        ),
      ],
    );

    final banner = !flagged
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    [
                      for (final issue in widget.issues)
                        visionIssueMessage(issue, widget.check),
                    ].join('\n'),
                    key: ValueKey('image-row-issue-$i'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.warn,
                    ),
                  ),
                ),
                // 금액이 없는 줄은 맞다고 할 수 없다. 금액을 넣어야 풀린다.
                if (!widget.issues.contains(VisionIssue.amountMissing))
                  TextButton(
                    key: ValueKey('image-row-confirm-$i'),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.warn,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: widget.onConfirm,
                    child: const Text('맞음'),
                  ),
              ],
            ),
          );

    final editor = !_open
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('image-row-date-$i'),
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(row.date.toString()),
                ),
                SegmentedButton<Direction>(
                  key: ValueKey('image-row-direction-$i'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: Direction.outgoing,
                      label: Text('지출', key: ValueKey('image-row-out-$i')),
                    ),
                    ButtonSegment(
                      value: Direction.incoming,
                      label: Text('수입', key: ValueKey('image-row-in-$i')),
                    ),
                  ],
                  selected: {
                    incoming ? Direction.incoming : Direction.outgoing,
                  },
                  onSelectionChanged: (selected) => widget.onEdit(
                    (r) => r.copyWith(direction: selected.single),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    key: ValueKey('image-row-amount-$i'),
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    textAlign: TextAlign.end,
                    style: tokens.amountStyle(theme.textTheme.bodyMedium),
                    decoration: const InputDecoration(
                      labelText: '금액',
                      suffixText: '원',
                      isDense: true,
                    ),
                    onChanged: (text) {
                      final value = parseAmountInput(text);
                      widget.onEdit(
                        (r) => r.copyWith(
                          amount: (value == null || value == 0) ? null : value,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    key: ValueKey('image-row-who-$i'),
                    controller: _who,
                    inputFormatters: [LengthLimitingTextInputFormatter(60)],
                    decoration: const InputDecoration(
                      labelText: '상대방',
                      isDense: true,
                    ),
                    onChanged: (text) =>
                        widget.onEdit((r) => r.copyWith(counterparty: text)),
                  ),
                ),
              ],
            ),
          );

    return Opacity(
      opacity: widget.included ? 1 : 0.5,
      child: Material(
        key: ValueKey('image-row-$i'),
        color: flagged ? tokens.warnSoft : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radius),
          side: BorderSide(color: flagged ? tokens.warn : tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [summary, ?banner, ?editor],
        ),
      ),
    );
  }
}
