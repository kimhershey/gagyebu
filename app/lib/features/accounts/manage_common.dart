/// 관리 화면(자산 · 분류 · 예산 · 반복 거래)이 함께 쓰는 위젯.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/breakpoints.dart';
import '../../core/formatters.dart';
import '../common/widgets.dart';

/// 목록의 바깥 여백. 아래를 넉넉히 두어, 맨 아래 줄을 방금 뜬 알림 위로 올려 누를 수 있게
/// 한다.
const manageListPadding = EdgeInsets.fromLTRB(16, 16, 16, 96);

/// 화면 맨 위의 제목 줄.
///
/// 이 화면들은 탭이 아니라서 휴대폰과 태블릿에서는 설정에서 들어온다. 돌아갈 길이 보이게
/// '설정으로' 단추를 둔다. 넓은 창의 옆 메뉴에 있는 화면([inSideMenu])은 거기서는 뺀다.
class ManageHeader extends StatelessWidget {
  const ManageHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.inSideMenu = false,
  });

  final String title;
  final List<Widget> actions;
  final bool inSideMenu;

  @override
  Widget build(BuildContext context) {
    final showBack = !(inSideMenu && WindowSize.of(context).isExpanded);
    return Row(
      children: [
        if (showBack)
          IconButton(
            key: const ValueKey('manage-back'),
            tooltip: '설정으로',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.arrow_back),
          ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// 비동기 값의 불러오는 중 · 오류 · 내용을 그린다.
///
/// 오류는 예외 문구를 보이지 않고, [what]을 불러오지 못했다는 것과 다시 해 볼 단추를 둔다.
class ManageAsync<T> extends StatelessWidget {
  const ManageAsync({
    super.key,
    required this.value,
    required this.what,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;

  /// '자산을'처럼 조사를 붙인 이름.
  final String what;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return builder(value.requireValue);
    if (value.hasError) {
      return EmptyState(
        icon: Icons.error_outline,
        message: '$what 불러오지 못했습니다.\n잠시 뒤에 다시 시도해 주세요.',
        action: OutlinedButton(
          key: const ValueKey('manage-retry'),
          onPressed: onRetry,
          child: const Text('다시 시도'),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 이름과 금액을 한 줄에 둔다. 칸이 좁거나 글자가 크면 금액을 아랫줄로 내려 넘치지 않게
/// 한다. 금액은 줄을 바꾸지 않고, 그래도 넘치면 줄여 그린다.
class LabelAmountRow extends StatelessWidget {
  const LabelAmountRow({super.key, required this.label, required this.amount});

  final Widget label;
  final Widget amount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final fitted = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: amount,
        );
        if (constraints.maxWidth < 200 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label,
              Align(alignment: Alignment.centerRight, child: fitted),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
              child: fitted,
            ),
          ],
        );
      },
    );
  }
}

/// 편집 칸을 연다. 좁은 창에서는 전체 화면으로, 그 밖에서는 가운데 대화상자로 연다.
Future<T?> showEditor<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final compact = WindowSize.of(context).isCompact;
  return showDialog<T>(
    context: context,
    builder: (context) => compact
        ? Dialog.fullscreen(child: SafeArea(child: builder(context)))
        : Dialog(
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: builder(context),
            ),
          ),
  );
}

/// 편집 칸의 틀: 제목과 닫기, 스크롤되는 내용, 아래의 단추들.
class EditorFrame extends StatelessWidget {
  const EditorFrame({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const ValueKey('editor-close'),
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              // 입력 칸의 이름표가 위로 떠오를 자리.
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 글자가 커지면 단추가 다음 줄로 내려간다.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      ),
    );
  }
}

/// 되돌릴 수 없는 일을 하기 전에 묻는다. 하겠다고 하면 true.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '삭제',
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('confirm-yes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return answer ?? false;
}

/// 알림 한 줄을 띄운다. 앞의 알림은 치운다.
void showNotice(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 금액 입력 칸에 천 단위 쉼표를 넣는다. [allowNegative]면 맨 앞의 '-'를 받는다.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter({this.allowNegative = false});

  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final negative = allowNegative && newValue.text.trimLeft().startsWith('-');
    final amount = parseAmountInput(newValue.text);
    final text = amount == null
        ? (negative ? '-' : '')
        : '${negative ? '-' : ''}${formatNumber(amount)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// 입력 칸의 글자에서 부호가 있는 금액을 읽는다. '-50,000' → -50000. 숫자가 없으면 null.
int? parseSignedAmount(String text) {
  final amount = parseAmountInput(text);
  if (amount == null) return null;
  return text.trimLeft().startsWith('-') ? -amount : amount;
}

/// 끌어서 순서를 바꾼 뒤 저장이 끝나 목록이 다시 올 때까지 새 순서로 보여 준다.
///
/// 저장은 금방 끝나지만 그사이 옛 순서로 한 번 그려지면 줄이 튀어 보인다.
List<T> applyPendingOrder<T>(
  List<T> items,
  List<String>? pending,
  String Function(T item) idOf,
) {
  if (pending == null) return items;
  final byId = {for (final item in items) idOf(item): item};
  // 그사이 줄이 더해지거나 지워졌으면 받은 목록을 그대로 쓴다.
  if (pending.length != items.length || pending.any((id) => byId[id] == null)) {
    return items;
  }
  return [for (final id in pending) byId[id] as T];
}
