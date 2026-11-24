import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../data/db/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../domain/enums.dart';
import '../accounts/manage_common.dart';
import '../common/category_visual.dart';
import '../common/widgets.dart';
import 'category_form.dart';
import 'category_tree.dart';

/// 분류 화면. `docs/SPEC.md` 7.2.
///
/// 지출 · 수입 탭마다 대분류와 그 아래의 소분류를 보여 준다. 줄을 누르면 고치고, 길게 눌러
/// 끌거나 손잡이를 끌면 같은 자리의 분류끼리 순서가 바뀐다.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: CategoryKind.values.length,
    vsync: this,
  );

  /// 방금 끌어 놓은 순서. 키는 묶음(종류, 또는 대분류의 ID)이다.
  final _pendingOrder = <String, List<String>>{};

  CategoryKind get _kind => CategoryKind.values[_tabs.index];

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openForm({CategoryRow? existing}) => showEditor<void>(
    context,
    builder: (context) =>
        CategoryForm(kind: existing?.kind ?? _kind, existing: existing),
  );

  Future<void> _reorder(String key, List<String> ids, int from, int to) async {
    final order = [...ids];
    order.insert(to, order.removeAt(from));
    setState(() => _pendingOrder[key] = order);
    try {
      await ref
          .read(categoryRepositoryProvider)
          .reorderCategories(ref.read(ledgerIdProvider), order);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pendingOrder.remove(key));
      showNotice(context, '순서를 바꾸지 못했습니다. 잠시 뒤에 다시 시도해 주세요.');
    }
  }

  /// [items]를 방금 끌어 놓은 순서로 늘어놓는다. 저장된 순서가 따라왔으면 그만 붙든다.
  List<T> _ordered<T>(String key, List<T> items, String Function(T) idOf) {
    final pending = _pendingOrder[key];
    if (pending == null) return items;
    if (listEquals(pending, [for (final item in items) idOf(item)])) {
      _pendingOrder.remove(key);
      return items;
    }
    return applyPendingOrder(items, pending, idOf);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return SafeArea(
      child: ListView(
        padding: manageListPadding,
        children: [
          ManageHeader(
            title: '분류',
            actions: [
              FilledButton.tonalIcon(
                key: const ValueKey('categories-add'),
                onPressed: _openForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(key: ValueKey('categories-tab-expense'), text: '지출'),
              Tab(key: ValueKey('categories-tab-income'), text: '수입'),
            ],
          ),
          const SizedBox(height: 12),
          ManageAsync<List<CategoryRow>>(
            value: categories,
            what: '분류를',
            onRetry: () => ref.invalidate(categoriesProvider),
            builder: (all) => _buildList(buildCategoryGroups(all, _kind)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<CategoryGroup> stored) {
    final kindName = _kind == CategoryKind.expense ? '지출' : '수입';
    if (stored.isEmpty) {
      return EmptyState(
        icon: Icons.label_outline,
        message: '$kindName 분류가 없습니다.\n분류를 만들면 거래를 나눠 볼 수 있습니다.',
        action: FilledButton(
          key: const ValueKey('categories-add-first'),
          onPressed: _openForm,
          child: const Text('분류 추가'),
        ),
      );
    }
    final key = 'kind:${_kind.code}';
    final groups = _ordered(key, stored, (g) => g.category.id);
    final ids = [for (final g in groups) g.category.id];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ReorderableListView.builder(
        key: ValueKey('categories-list-${_kind.code}'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: groups.length,
        onReorderItem: (from, to) => _reorder(key, ids, from, to),
        itemBuilder: (context, index) => _buildGroup(
          groups[index],
          index: index,
          reorderable: groups.length > 1,
        ),
      ),
    );
  }

  Widget _buildGroup(
    CategoryGroup group, {
    required int index,
    required bool reorderable,
  }) {
    final key = 'parent:${group.category.id}';
    final children = _ordered(key, group.children, (c) => c.category.id);
    final childIds = [for (final c in children) c.category.id];
    return Material(
      key: ValueKey('category-group-${group.category.id}'),
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CategoryTile(
            category: group.category,
            colorIndex: group.colorIndex,
            index: index,
            reorderable: reorderable,
            childCount: children.length,
            onTap: () => _openForm(existing: group.category),
          ),
          if (children.isNotEmpty)
            // 소분류는 그 대분류 안에서만 순서를 바꾼다.
            ReorderableListView.builder(
              key: ValueKey('category-children-${group.category.id}'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: children.length,
              onReorderItem: (from, to) => _reorder(key, childIds, from, to),
              itemBuilder: (context, childIndex) => Material(
                key: ValueKey(
                  'category-child-${children[childIndex].category.id}',
                ),
                type: MaterialType.transparency,
                child: _CategoryTile(
                  category: children[childIndex].category,
                  colorIndex: children[childIndex].colorIndex,
                  index: childIndex,
                  reorderable: children.length > 1,
                  indent: true,
                  onTap: () =>
                      _openForm(existing: children[childIndex].category),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 분류 한 줄: 색 점, 아이콘, 이름, 손잡이.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.colorIndex,
    required this.index,
    required this.reorderable,
    required this.onTap,
    this.indent = false,
    this.childCount = 0,
  });

  final CategoryRow category;
  final int colorIndex;
  final int index;
  final bool reorderable;
  final VoidCallback onTap;

  /// 소분류면 들여 쓴다.
  final bool indent;
  final int childCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final color = categoryColor(tokens, colorIndex);
    final row = InkWell(
      key: ValueKey('category-${category.id}'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // 촘촘한 톤에서도 누름 영역은 48을 지킨다.
          minHeight: tokens.rowHeight < 48 ? 48 : tokens.rowHeight,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(indent ? 44 : 16, 4, 4, 4),
          child: Row(
            children: [
              // 색만으로 가르지 않게 아이콘을 함께 둔다.
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Icon(
                categoryIcon(category.name, category.icon),
                size: indent ? 20 : 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: indent
                      ? theme.textTheme.bodyMedium
                      : theme.textTheme.bodyLarge,
                ),
              ),
              if (childCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '소분류 $childCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (reorderable)
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: '끌어서 순서 바꾸기',
                    child: SizedBox(
                      key: ValueKey('category-handle-${category.id}'),
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.drag_handle,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
    // 터치 기기에서는 줄을 길게 눌러 끌 수 있다.
    return reorderable
        ? ReorderableDelayedDragStartListener(index: index, child: row)
        : row;
  }
}
