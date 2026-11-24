import '../../data/db/database.dart';
import '../../domain/enums.dart';

/// 대분류 하나와 그 아래의 소분류.
class CategoryGroup {
  const CategoryGroup({
    required this.category,
    required this.colorIndex,
    required this.children,
  });

  final CategoryRow category;

  /// 분류 색의 자리(`categoryColor`에 넘긴다).
  final int colorIndex;
  final List<CategoryChild> children;
}

/// 소분류 한 줄.
class CategoryChild {
  const CategoryChild({required this.category, required this.colorIndex});

  final CategoryRow category;
  final int colorIndex;
}

/// [all](`sort_order` 순서) 가운데 [kind]의 분류를 대분류와 소분류로 묶는다.
///
/// 색의 자리는 그 종류의 분류를 `sort_order`로 늘어놓았을 때의 차례다(`docs/SPEC.md` 6.1).
/// 대분류가 지워졌거나 아직 받지 못한 소분류는 대분류 없는 분류로 보인다. 소분류의
/// 소분류(다른 기기에서 잘못 만들어진 경우)도 맨 위로 올려 한 단계만 그린다.
List<CategoryGroup> buildCategoryGroups(
  List<CategoryRow> all,
  CategoryKind kind,
) {
  final ofKind = [
    for (final c in all)
      if (c.kind == kind) c,
  ];
  final colorIndex = {for (var i = 0; i < ofKind.length; i++) ofKind[i].id: i};
  final byId = {for (final c in ofKind) c.id: c};
  bool isRoot(CategoryRow c) {
    final parent = byId[c.parentId];
    return parent == null || parent.parentId != null || parent.id == c.id;
  }

  return [
    for (final root in ofKind)
      if (isRoot(root))
        CategoryGroup(
          category: root,
          colorIndex: colorIndex[root.id]!,
          children: [
            for (final c in ofKind)
              if (!isRoot(c) && c.parentId == root.id)
                CategoryChild(category: c, colorIndex: colorIndex[c.id]!),
          ],
        ),
  ];
}

/// 아이콘 고르기에서 읽어 주는 이름. 키는 `categoryIconChoices`의 키다.
const categoryIconLabels = <String, String>{
  'restaurant': '식당',
  'cafe': '카페',
  'grocery': '장보기',
  'bus': '버스',
  'car': '자동차',
  'fuel': '주유',
  'home': '집',
  'phone': '휴대폰',
  'bolt': '전기',
  'cart': '장바구니',
  'bag': '쇼핑백',
  'clothes': '옷',
  'health': '병원',
  'pharmacy': '약',
  'fitness': '운동',
  'school': '학교',
  'book': '책',
  'movie': '영화',
  'game': '게임',
  'travel': '여행',
  'hotel': '숙박',
  'gift': '선물',
  'celebration': '축하',
  'bank': '은행',
  'insurance': '보험',
  'card': '카드',
  'savings': '저축',
  'salary': '급여',
  'allowance': '용돈',
  'interest': '이자',
  'pet': '반려동물',
  'child': '아이',
  'beauty': '미용',
  'laundry': '세탁',
  'subscription': '구독',
  'tax': '세금',
  'donation': '기부',
  'tools': '수리',
  'more': '기타',
  'label': '꼬리표',
};
