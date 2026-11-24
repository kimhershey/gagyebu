import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import 'shortcuts.dart';

/// 단축키 도움말을 대화상자로 연다.
Future<void> showShortcutsHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => const ShortcutsHelpDialog(),
);

/// 도움말의 한 줄: 누르는 키들과 하는 일.
typedef _Entry = (List<String> keys, String action);

/// 단축키를 표로 보여 주는 대화상자(`docs/SPEC.md` 7.8의 표).
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <(String, List<_Entry>)>[
      (
        '어디서나',
        [
          ([modifierShortcut('K')], '입력창(명령창)으로'),
        ],
      ),
      (
        '글 칸 밖에서',
        [
          (['/'], '내역 검색'),
          (['?'], '단축키 도움말'),
          (['['], '이전 달'),
          ([']'], '다음 달'),
          ([modifierShortcut('Z')], '마지막 입력 묶음 되돌리기'),
        ],
      ),
      (
        '입력창에서',
        [
          (['Enter'], '적은 글을 거래로 해석'),
          (['Shift+Enter'], '줄바꿈'),
          (['>'], '명령만 찾기'),
          (['↑', '↓', 'Enter'], '명령 고르기 · 실행'),
        ],
      ),
      (
        '검토 중일 때',
        [
          ([modifierShortcut('Enter')], '모두 승인하고 저장'),
          (['↑', '↓'], '건 이동'),
          (['Space'], '포함 · 제외'),
          (['Enter'], '고치기'),
          (['Delete'], '제외'),
          (['Esc'], '닫기(버릴지 묻습니다)'),
        ],
      ),
    ];

    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('shortcuts-help'),
      title: const Text('단축키'),
      // 글자를 크게 쓰거나 창이 낮아도 끝까지 볼 수 있게 한다.
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, (title, entries)) in sections.indexed) ...[
              if (index > 0) const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Table(
                // 키가 여럿이면 줄이 바뀌므로 두 칸 모두 너비를 나눠 갖는다.
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(3),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  for (final (keys, action) in entries)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final key in keys) ShortcutLabel(key),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(action),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '글자 한 개짜리 단축키는 글 칸에 커서가 있을 때는 듣지 않습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('shortcuts-help-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

/// 키 하나의 표기('Ctrl+K')를 자판의 키처럼 그린다.
class ShortcutLabel extends StatelessWidget {
  const ShortcutLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        label,
        style: tokens.amountStyle(
          theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
