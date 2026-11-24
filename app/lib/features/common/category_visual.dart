import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';

/// 분류의 색: 팔레트의 열두 색을 분류의 자리([index], 0부터)대로 돌려 쓴다.
///
/// 색을 DB에 두지 않는다. 테마를 바꾸면 그 팔레트의 색으로 바뀐다.
Color categoryColor(AppTokens tokens, int index) =>
    tokens.categoryColors[index % tokens.categoryColors.length];

/// 분류의 아이콘. [icon](`categories.icon`에 적힌 이름)이 있으면 그것을, 없으면 기본
/// 분류 [name]에 맞는 것을, 그것도 없으면 꼬리표를 쓴다.
IconData categoryIcon(String name, String? icon) =>
    categoryIconChoices[icon] ??
    categoryIconChoices[_defaultIconNames[name]] ??
    Icons.label_outline;

/// 분류에 고를 수 있는 아이콘. 키가 `categories.icon`에 적는 이름이다.
const categoryIconChoices = <String, IconData>{
  'restaurant': Icons.restaurant,
  'cafe': Icons.local_cafe,
  'grocery': Icons.local_grocery_store,
  'bus': Icons.directions_bus,
  'car': Icons.directions_car,
  'fuel': Icons.local_gas_station,
  'home': Icons.home_outlined,
  'phone': Icons.phone_iphone,
  'bolt': Icons.bolt,
  'cart': Icons.shopping_cart_outlined,
  'bag': Icons.shopping_bag_outlined,
  'clothes': Icons.checkroom,
  'health': Icons.local_hospital_outlined,
  'pharmacy': Icons.medication_outlined,
  'fitness': Icons.fitness_center,
  'school': Icons.school_outlined,
  'book': Icons.menu_book,
  'movie': Icons.movie_outlined,
  'game': Icons.sports_esports_outlined,
  'travel': Icons.flight,
  'hotel': Icons.hotel_outlined,
  'gift': Icons.card_giftcard,
  'celebration': Icons.celebration_outlined,
  'bank': Icons.account_balance_outlined,
  'insurance': Icons.shield_outlined,
  'card': Icons.credit_card,
  'savings': Icons.savings_outlined,
  'salary': Icons.work_outline,
  'allowance': Icons.volunteer_activism_outlined,
  'interest': Icons.trending_up,
  'pet': Icons.pets,
  'child': Icons.child_care,
  'beauty': Icons.content_cut,
  'laundry': Icons.local_laundry_service_outlined,
  'subscription': Icons.subscriptions_outlined,
  'tax': Icons.receipt_long_outlined,
  'donation': Icons.favorite_border,
  'tools': Icons.build_outlined,
  'more': Icons.more_horiz,
  'label': Icons.label_outline,
};

/// 기본 분류(`domain/default_seed.dart`)의 아이콘.
const _defaultIconNames = <String, String>{
  '식비': 'restaurant',
  '카페·간식': 'cafe',
  '교통': 'bus',
  '주거·통신': 'home',
  '생활': 'cart',
  '쇼핑': 'bag',
  '의료·건강': 'health',
  '교육': 'school',
  '문화·여가': 'movie',
  '경조사·선물': 'gift',
  '금융·보험': 'bank',
  '기타지출': 'more',
  '급여': 'salary',
  '용돈': 'allowance',
  '금융수익': 'interest',
  '기타수입': 'more',
};
