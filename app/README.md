# app/

Flutter 앱이다. 개발 방법은 저장소 맨 위의 README를 본다.

- 시작점: `lib/main.dart` → `lib/app/bootstrap.dart`(로컬 DB 열기) → `lib/app/app.dart`
- 화면과 주소: `lib/app/router.dart`
- 창 너비 등급: `lib/core/breakpoints.dart` (600dp 미만 · 600–839dp · 840dp 이상)
- 문자 형식 규칙: `lib/ai/text/sms_rules.dart`
- 로컬 테이블: `lib/data/db/tables.dart` (고치면 `dart run build_runner build`)
