import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../domain/enums.dart';
import '../accounts/manage_common.dart';
import '../common/category_visual.dart';
import 'category_tree.dart';

/// 분류를 더하거나 고치는 칸. [existing]이 있으면 고친다.
class CategoryForm extends ConsumerStatefulWidget {
  const CategoryForm({super.key, required this.kind, this.existing});

  /// 새 분류의 종류. 고칠 때는 [existing]의 종류와 같다.
  final CategoryKind kind;
  final CategoryRow? existing;

  @override
  ConsumerState<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  String? _icon;
  String? _parentId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    _name = TextEditingController(text: row?.name ?? '');
    // 목록에 없는 이름(다른 판의 앱이 적은 값)은 고르지 않은 것으로 본다.
    _icon = categoryIconChoices.containsKey(row?.icon) ? row?.icon : null;
    _parentId = row?.parentId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    final categories = ref.read(categoryRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (existing == null) {
        final id = await ref
            .read(repositoryProvider)
            .addCategory(
              ledgerId: ref.read(ledgerIdProvider),
              kind: widget.kind,
              name: _name.text,
              parentId: _parentId,
            );
        if (_icon != null) {
          await categories.updateCategory(id, name: _name.text, icon: _icon);
        }
      } else {
        await categories.updateCategory(
          existing.id,
          name: _name.text,
          icon: _icon,
        );
        if (_parentId != existing.parentId) {
          await categories.setParent(existing.id, _parentId);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showNotice(context, existing == null ? '분류를 추가했습니다.' : '분류를 고쳤습니다.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showNotice(context, '저장하지 못했습니다. 입력한 내용을 확인하고 다시 시도해 주세요.');
    }
  }

  Future<void> _delete(int childCount) async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await confirmAction(
      context,
      title: '${existing.name} 분류를 지울까요?',
      message: [
        "이 분류를 쓰던 거래는 '분류 없음'이 됩니다.",
        if (childCount > 0) '소분류 $childCount개는 대분류 없는 분류가 됩니다.',
      ].join('\n'),
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(categoryRepositoryProvider).deleteCategory(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      showNotice(context, '${existing.name} 분류를 지웠습니다.');
    } catch (_) {
      if (mounted) showNotice(context, '지우지 못했습니다. 잠시 뒤에 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = widget.existing;
    final all = ref.watch(categoriesProvider).value ?? const <CategoryRow>[];
    final groups = buildCategoryGroups(all, widget.kind);
    final childCount = existing == null
        ? 0
        : groups
                  .where((g) => g.category.id == existing.id)
                  .firstOrNull
                  ?.children
                  .length ??
              0;
    // 대분류로 고를 수 있는 분류: 같은 종류의 대분류 가운데 자기 자신이 아닌 것.
    final parentOptions = [
      for (final g in groups)
        if (g.category.id != existing?.id) g.category,
    ];
    final parentValue = parentOptions.any((c) => c.id == _parentId)
        ? _parentId
        : null;
    const gap = SizedBox(height: 12);

    return Form(
      key: _formKey,
      child: EditorFrame(
        title: existing == null
            ? (widget.kind == CategoryKind.expense ? '지출 분류 추가' : '수입 분류 추가')
            : '분류 고치기',
        actions: [
          if (existing != null)
            TextButton(
              key: const ValueKey('category-form-delete'),
              onPressed: _saving ? null : () => _delete(childCount),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('삭제'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('category-form-save'),
            onPressed: _saving ? null : _save,
            child: Text(existing == null ? '추가' : '저장'),
          ),
        ],
        children: [
          TextFormField(
            key: const ValueKey('category-form-name'),
            controller: _name,
            autofocus: existing == null,
            decoration: const InputDecoration(labelText: '이름'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? '이름을 넣어야 합니다' : null,
          ),
          gap,
          DropdownButtonFormField<String?>(
            key: const ValueKey('category-form-parent'),
            initialValue: parentValue,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '대분류',
              helperText: childCount > 0
                  ? '소분류가 있는 분류는 다른 분류 아래에 둘 수 없습니다'
                  : '고르면 그 분류의 소분류가 됩니다',
              helperMaxLines: 3,
            ),
            items: [
              const DropdownMenuItem<String?>(child: Text('없음')),
              for (final c in parentOptions)
                DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(c.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            // 소분류는 한 단계만 둔다.
            onChanged: childCount > 0
                ? null
                : (value) => setState(() => _parentId = value),
          ),
          gap,
          Text('아이콘', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _IconChoice(
                key: const ValueKey('category-icon-default'),
                icon: categoryIcon(_name.text.trim(), null),
                label: '기본',
                selected: _icon == null,
                onTap: () => setState(() => _icon = null),
              ),
              for (final entry in categoryIconChoices.entries)
                _IconChoice(
                  key: ValueKey('category-icon-${entry.key}'),
                  icon: entry.value,
                  label: categoryIconLabels[entry.key] ?? entry.key,
                  selected: _icon == entry.key,
                  onTap: () => setState(() => _icon = entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 아이콘 고르기의 한 칸.
class _IconChoice extends StatelessWidget {
  const _IconChoice({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: label,
      isSelected: selected,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: selected ? scheme.secondaryContainer : null,
        foregroundColor: selected
            ? scheme.onSecondaryContainer
            : scheme.onSurfaceVariant,
        side: selected ? BorderSide(color: scheme.primary) : null,
      ),
      icon: Icon(icon),
    );
  }
}
