import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/formatters.dart';
import '../../core/local_date.dart';
import '../../domain/enums.dart';
import '../common/widgets.dart';
import '../settings/sub_screen.dart';
import 'csv_codec.dart';
import 'export.dart';
import 'export_queries.dart';
import 'file_access.dart';
import 'import_mapping.dart';

/// 내보내기 · 가져오기 화면(`docs/SPEC.md` 7.16).
class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) => const SubScreen(
    title: '내보내기 · 가져오기',
    children: [_ExportCard(), SizedBox(height: 12), _ImportCard()],
  );
}

// ---------------------------------------------------------------------- 내보내기

/// 내보낼 기간을 고르는 방법.
enum _Range { month, year, all, custom }

class _ExportCard extends ConsumerStatefulWidget {
  const _ExportCard();

  @override
  ConsumerState<_ExportCard> createState() => _ExportCardState();
}

class _ExportCardState extends ConsumerState<_ExportCard> {
  _Range _range = _Range.month;
  ExportFormat _format = ExportFormat.csv;

  /// 직접 고른 기간(끝 날짜 포함).
  (LocalDate, LocalDate)? _custom;
  bool _busy = false;

  /// 마지막으로 내보낸 결과나 실패를 알리는 말.
  String? _result;
  bool _failed = false;

  /// 내보낼 기간: 시작, 끝 다음 날, 파일 이름에 붙일 말.
  (LocalDate, LocalDate, String) _span() {
    final today = ref.read(todayProvider);
    switch (_range) {
      case _Range.month:
        final period = ref.read(selectedPeriodProvider);
        return (
          period.start,
          period.endExclusive,
          '${period.start}_${period.last}',
        );
      case _Range.year:
        return (
          LocalDate(today.year, 1, 1),
          LocalDate(today.year + 1, 1, 1),
          '${today.year}',
        );
      case _Range.all:
        return (LocalDate(1, 1, 1), LocalDate(9999, 12, 31), '전체');
      case _Range.custom:
        final (from, to) = _custom ?? (today, today);
        return (from, to.addDays(1), '${from}_$to');
    }
  }

  Future<void> _pickCustom() async {
    final today = ref.read(todayProvider);
    final (from, to) = _custom ?? (today.addMonths(-1), today);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: from.toDateTime(),
        end: to.toDateTime(),
      ),
      helpText: '내보낼 기간',
      saveText: '고르기',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = _Range.custom;
      _custom = (
        LocalDate.fromDateTime(picked.start),
        LocalDate.fromDateTime(picked.end),
      );
    });
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _result = null;
      _failed = false;
    });
    final (from, toExclusive, name) = _span();
    final format = _format;
    // 기다리는 사이에 화면이 닫힐 수 있다. 필요한 것을 미리 잡아 둔다.
    final repository = ref.read(repositoryProvider);
    final ledgerId = ref.read(ledgerIdProvider);
    final save = ref.read(fileSaverProvider);
    String message;
    var failed = false;
    try {
      final rows = await repository.transactionsBetween(
        ledgerId,
        from: from,
        toExclusive: toExclusive,
      );
      if (rows.isEmpty) {
        message = '이 기간에는 내보낼 거래가 없습니다.';
      } else {
        final bytes = exportTransactions(rows, format);
        final saved = await save(
          fileName: '가계부_$name.${format.extension}',
          mimeType: format.mimeType,
          bytes: bytes,
        );
        message = saved == null
            ? '저장하지 않았습니다.'
            : '거래 ${formatNumber(rows.length)}건을 저장했습니다: $saved';
      }
    } on Object {
      failed = true;
      message = '파일을 저장하지 못했습니다. 저장할 곳을 쓸 수 있는지 확인하고 다시 해 주십시오.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = message;
      _failed = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final period = ref.watch(selectedPeriodProvider);
    final today = ref.watch(todayProvider);
    final custom = _custom;

    Widget rangeChip(_Range range, String label, {VoidCallback? onTap}) =>
        ChoiceChip(
          key: ValueKey('export-range-${range.name}'),
          label: Text(label),
          selected: _range == range,
          onSelected: _busy
              ? null
              : (_) => onTap != null ? onTap() : setState(() => _range = range),
        );

    return SectionCard(
      title: '내보내기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HintText(
            '고른 기간의 거래를 파일로 저장합니다. 열은 날짜, 시각, 종류, 금액, 자산, '
            '받는 자산, 상대방, 분류, 메모, 할부, 취소 여부입니다.',
          ),
          const SizedBox(height: 12),
          const Text('기간'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              rangeChip(_Range.month, periodLabel(period)),
              rangeChip(_Range.year, '${today.year}년'),
              rangeChip(_Range.all, '전체'),
              rangeChip(
                _Range.custom,
                custom == null ? '직접 고르기' : '${custom.$1} – ${custom.$2}',
                onTap: _pickCustom,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('형식'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final format in ExportFormat.values)
                ChoiceChip(
                  key: ValueKey('export-format-${format.name}'),
                  label: Text(format.label),
                  selected: _format == format,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _format = format),
                ),
            ],
          ),
          const SizedBox(height: 6),
          HintText(
            _format == ExportFormat.csv
                ? 'CSV는 Excel과 다른 가계부 앱이 읽습니다. 이 앱으로 다시 가져올 수 있습니다.'
                : 'Excel 파일(.xlsx)입니다. 이 앱으로 다시 가져오려면 CSV로 내보내 주십시오.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('export-run'),
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: Text(_busy ? '내보내는 중입니다' : '내보내기'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 8),
            Text(
              _result!,
              key: const ValueKey('export-result'),
              style: TextStyle(color: _failed ? scheme.error : null),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------- 가져오기

class _ImportCard extends ConsumerStatefulWidget {
  const _ImportCard();

  @override
  ConsumerState<_ImportCard> createState() => _ImportCardState();
}

class _ImportCardState extends ConsumerState<_ImportCard> {
  String? _fileName;
  CsvTable? _table;
  ColumnMapping _mapping = const ColumnMapping({});
  bool _busy = false;
  String? _error;

  /// 가계부에 없는 자산 · 분류를 새로 만들지.
  bool _createMissing = false;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    PickedFile? picked;
    CsvTable? table;
    try {
      picked = await ref.read(filePickerProvider)();
      if (picked != null) table = parseCsv(picked.bytes);
    } on FileTooLargeException {
      error = '파일이 너무 큽니다. 20MB까지 읽을 수 있습니다. 파일을 나눠 주십시오.';
    } on FormatException {
      error = '파일에서 표를 읽지 못했습니다. CSV 파일인지 확인해 주십시오.';
    } on Object {
      error = '파일을 열지 못했습니다. 다시 골라 주십시오.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (table != null) {
        _fileName = picked!.name;
        _table = table;
        _mapping = guessMapping(table.header);
        _createMissing = false;
      }
    });
  }

  void _clear() => setState(() {
    _fileName = null;
    _table = null;
    _mapping = const ColumnMapping({});
    _error = null;
  });

  Future<void> _send(
    Future<void> Function(List<ImportedRow>) sink,
    ImportResult result,
    MissingNames missing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_createMissing) {
        final repository = ref.read(repositoryProvider);
        final ledgerId = ref.read(ledgerIdProvider);
        for (final name in missing.accounts) {
          // 종류는 파일에 없다. '기타'로 만들고 자산 화면에서 고치게 한다.
          await repository.addAccount(
            ledgerId: ledgerId,
            name: name,
            kind: AccountKind.other,
          );
        }
        for (final entry in missing.categories.entries) {
          await repository.addCategory(
            ledgerId: ledgerId,
            kind: entry.value,
            name: entry.key,
          );
        }
      }
      await sink(result.rows);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${formatNumber(result.rows.length)}건을 검토함으로 보냈습니다'),
        ),
      );
      setState(() {
        _busy = false;
        _fileName = null;
        _table = null;
        _mapping = const ColumnMapping({});
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '검토함으로 보내지 못했습니다. 다시 해 주십시오.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final table = _table;
    final sink = ref.watch(importSinkProvider);

    final children = <Widget>[
      const HintText(
        'CSV 파일의 거래를 읽어 옵니다. 이 앱이 내보낸 파일은 그대로 읽고, 은행 · 카드사의 '
        '파일은 열을 맞춰서 읽습니다. 한 번에 2,000건까지 읽고, 읽은 건은 검토함에서 '
        '확인한 뒤에 저장됩니다.',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('import-pick'),
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(table == null ? '파일 고르기' : '다른 파일 고르기'),
          ),
          if (table != null)
            TextButton(
              key: const ValueKey('import-clear'),
              onPressed: _busy ? null : _clear,
              child: const Text('닫기'),
            ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          key: const ValueKey('import-error'),
          style: TextStyle(color: scheme.error),
        ),
      ],
    ];

    if (table != null) {
      final complete = _mapping.isComplete;
      final result = complete ? mapRows(table, _mapping) : null;
      children.addAll([
        const SizedBox(height: 12),
        Text(
          '$_fileName · ${table.encoding} · ${formatNumber(table.rows.length)}줄',
          key: const ValueKey('import-file'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        HintText(
          '${table.headerLine > 1 ? '표 위의 안내 ${table.headerLine - 1}줄은 건너뛰었습니다. ' : ''}'
          '제목 줄: ${table.header.join(' | ')}',
        ),
        const SizedBox(height: 8),
        if (_mapping.ownFormat)
          const Text(
            '이 앱이 내보낸 파일입니다. 열을 맞출 필요가 없습니다.',
            key: ValueKey('import-own-format'),
          )
        else ...[
          const Text('열 맞추기'),
          const SizedBox(height: 2),
          const HintText(
            '날짜 · 금액 · 내용은 꼭 맞춰야 합니다. 출금과 입금이 다른 열이면 금액 대신 '
            '그 두 열을 맞춥니다.',
          ),
          const SizedBox(height: 8),
          _MappingFields(
            // 다른 파일을 고르면 드롭다운이 새 짐작으로 다시 시작하게 한다.
            key: ObjectKey(table),
            header: table.header,
            mapping: _mapping,
            enabled: !_busy,
            onChanged: (field, column) =>
                setState(() => _mapping = _mapping.withField(field, column)),
          ),
        ],
        const SizedBox(height: 12),
        if (result == null)
          Text(
            '아직 맞추지 않은 열: ${_mapping.missing.join(', ')}',
            key: const ValueKey('import-missing'),
            style: TextStyle(color: context.tokens.warn),
          )
        else
          ..._preview(context, result, sink),
      ]);
    }

    return SectionCard(
      title: '가져오기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  List<Widget> _preview(
    BuildContext context,
    ImportResult result,
    Future<void> Function(List<ImportedRow>)? sink,
  ) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final missing = findMissingNames(
      result.rows,
      accountNames: [
        for (final a in ref.watch(accountsProvider).value ?? const []) a.name,
      ],
      categoryNames: [
        for (final c in ref.watch(categoriesProvider).value ?? const []) c.name,
      ],
    );
    final missingLine = [
      if (missing.accounts.isNotEmpty) '자산 ${missing.accounts.join(', ')}',
      if (missing.categories.isNotEmpty)
        '분류 ${missing.categories.keys.join(', ')}',
    ].join(' · ');

    return [
      Text(
        '${formatNumber(result.rows.length)}건을 읽었습니다',
        key: const ValueKey('import-count'),
        style: theme.textTheme.titleMedium,
      ),
      if (result.skipped.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${formatNumber(result.skipped.length)}줄은 건너뛰었습니다. '
            '${result.skipped.first.line}번째 줄: ${result.skipped.first.reason}',
            key: const ValueKey('import-skipped'),
            style: TextStyle(color: tokens.warn),
          ),
        ),
      if (result.overLimit > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '한 번에 ${formatNumber(importLimit)}건까지 가져옵니다. 뒤의 '
            '${formatNumber(result.overLimit)}줄은 읽지 않았습니다. 파일을 나눠서 가져와 주십시오.',
            key: const ValueKey('import-over-limit'),
            style: TextStyle(color: tokens.warn),
          ),
        ),
      const SizedBox(height: 8),
      if (result.rows.isEmpty)
        const HintText('가져올 거래가 없습니다. 열을 바르게 맞췄는지 확인해 주십시오.')
      else ...[
        const HintText('처음 몇 건입니다.'),
        for (final row in result.rows.take(5)) _PreviewRow(row: row),
      ],
      if (!missing.isEmpty) ...[
        const SizedBox(height: 8),
        if (sink == null)
          HintText('가계부에 없는 이름이 있습니다: $missingLine')
        else
          CheckboxListTile(
            key: const ValueKey('import-create-missing'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _createMissing,
            onChanged: _busy
                ? null
                : (value) => setState(() => _createMissing = value ?? false),
            title: const Text('가계부에 없는 자산과 분류를 새로 만듭니다'),
            subtitle: Text('$missingLine\n만들지 않으면 검토함에서 자산과 분류를 직접 고릅니다.'),
          ),
      ],
      // 검토함 쪽이 이어지기 전에는 미리보기까지만 보인다.
      if (sink != null && result.rows.isNotEmpty) ...[
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('import-send'),
          onPressed: _busy ? null : () => _send(sink, result, missing),
          child: Text(_busy ? '보내는 중입니다' : '검토함으로 보내기'),
        ),
      ],
    ];
  }
}

/// 칸마다 파일의 열을 고르는 드롭다운들.
class _MappingFields extends StatelessWidget {
  const _MappingFields({
    super.key,
    required this.header,
    required this.mapping,
    required this.enabled,
    required this.onChanged,
  });

  final List<String> header;
  final ColumnMapping mapping;
  final bool enabled;
  final void Function(ImportField field, int? column) onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 넓으면 두 줄로 나눠 놓는다.
        const gap = 12.0;
        final width = constraints.maxWidth >= 520
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final field in ImportField.values)
              SizedBox(
                width: width,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey('import-map-${field.name}'),
                  initialValue: mapping[field],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: field.label,
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(child: Text('맞추지 않음')),
                    for (final (index, name) in header.indexed)
                      DropdownMenuItem<int?>(
                        value: index,
                        child: Text(
                          name.isEmpty ? '${index + 1}번째 열' : name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: enabled
                      ? (value) => onChanged(field, value)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 가져올 건 한 줄: 날짜 · 내용, 오른쪽에 금액.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.row});

  final ImportedRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final (sign, color) = switch (row.type) {
      TxType.income => ('+', tokens.income),
      TxType.expense => ('-', tokens.expense),
      // 이체에는 부호를 붙이지 않는다.
      TxType.transfer => ('', tokens.transfer),
    };
    final title =
        row.counterparty ??
        (row.type == TxType.transfer
            ? '${row.accountName ?? ''} → ${row.toAccountName ?? ''}'
            : row.memo ?? '내용 없음');
    final detail = [
      monthDay(row.date),
      txTypeLabel(row.type),
      ?row.accountName,
      ?row.categoryName,
      if (row.canceled) '취소',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 큰 금액이나 큰 글자에서도 줄을 넘지 않게, 줄의 60%를 넘으면 줄여 그린다.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$sign${won(row.amount)}',
                  maxLines: 1,
                  style: tokens
                      .amountStyle(theme.textTheme.bodyLarge)
                      .copyWith(color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
