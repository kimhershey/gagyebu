/// 가계부를 처음 만들 때 넣는 기본 분류와 자산.
///
/// 서버의 가입 트리거(`supabase/migrations/0004_lifecycle.sql`)가 같은 목록을 만든다.
/// 이름을 바꾸면 양쪽과 `ai/text/category_hints.dart`를 함께 고친다.
library;

import 'enums.dart';

const defaultLedgerName = '내 가계부';
const defaultCashAccountName = '현금';

const defaultExpenseCategories = <String>[
  '식비',
  '카페·간식',
  '교통',
  '주거·통신',
  '생활',
  '쇼핑',
  '의료·건강',
  '교육',
  '문화·여가',
  '경조사·선물',
  '금융·보험',
  '기타지출',
];

const defaultIncomeCategories = <String>['급여', '용돈', '금융수익', '기타수입'];

/// 종류별 기본 분류 이름.
List<String> defaultCategoryNames(CategoryKind kind) => switch (kind) {
  CategoryKind.expense => defaultExpenseCategories,
  CategoryKind.income => defaultIncomeCategories,
};
