# 가계부

문자와 문장으로 적는 가계부다. Windows · Android · 웹에서 같은 화면을 쓰고, 결제 문자와 한 줄 문장을 **기기 안에서** 해석해 거래로 옮긴다. iPhone · iPad · Mac은 웹 앱으로 쓴다.

| 휴대폰 | 검토 카드 | PC |
| --- | --- | --- |
| ![홈](docs/screenshots/phone-home.png) | ![검토 카드](docs/screenshots/phone-review.png) | ![내역](docs/screenshots/desktop-transactions.png) |

## 지금 상태

0단계(기술 검증)를 진행하고 있다. 아래는 2026-11-17 기준이다.

| 항목 | 상태 | 확인 방법 |
| --- | --- | --- |
| 반응형 화면(홈 · 내역 · 통계 · 설정 · 입력) | 동작 | 위젯 시험, Chromium에서 360 · 720 · 1280 너비 확인 |
| 붙여넣기 해석(은행 · 카드 문자, 앱 알림 32개 형식) | 동작 | 골든 세트 49건 |
| 한 줄 입력(‘어제 점심 김밥천국 8천원 카드로’) | 규칙으로 동작 | 문장 40건, 처음 보는 문장 20건 중 17건 |
| 검토 후 저장, 중복 · 취소 · 해외 결제 안내 | 동작 | 위젯 시험 |
| 로컬 DB(SQLite, 웹은 SQLite WebAssembly) | 동작 | 단위 시험, 브라우저에서 새로 고침 뒤 유지 확인 |
| 기기 쪽 동기화 엔진(대기열 · push · pull · 충돌) | 서버 없이 검증 | 규약을 흉내 낸 메모리 서버로 시험 |
| 서버 SQL(스키마 · RLS · 동기화 함수) | 서버 없이 검증 | PostgreSQL 16에서 시험 10건(CI에서도 돈다) |
| 로그인(Google), 서버 동기화, 첫 로그인 때 기기의 가계부를 계정으로 옮기기 | 서버 없이 검증 | 가짜 로그인 · 가짜 서버로 전체 흐름 시험. 실제 Supabase 프로젝트로는 아직 돌려 보지 못했다 |
| Windows · Android 앱에서의 로그인 | 아직 없음 | 브라우저에서 로그인하고 앱으로 돌아오는 주소 등록이 남았다. 지금은 웹에서만 로그인한다 |
| 모르는 형식의 문자를 LLM으로 읽기 | 해석 경로와 평가 도구까지 동작 | PC의 llama.cpp 서버로 실측(`eval/README.md`). 앱 안에서 모델을 돌리는 연동은 아직 없다 |
| 월별 총평, 자연어 조회 | 아직 없음 | |
| 이미지 입력(VLM), 예산, 반복 거래, 내보내기 | 아직 없음 | |
| Android APK, Windows 빌드 | CI에서 빌드된다 | 2026-11-17 CI 통과. 실제 휴대폰 · PC에서 실행해 보지는 못했다 |

골든 세트의 일치율은 규칙을 만든 표본에 대한 회귀 검사다. 처음 보는 글에 대한 수치는 따로 지어낸 홀드아웃 표본으로 쟀고(`eval/README.md`), 모르는 형식의 문자에서 모든 항목이 맞은 초안은 규칙만 0/20, Qwen3.5-2B를 붙이면 13/20이었다. 실제 문자를 모아 다시 재야 한다.

## 폴더

```
app/                 Flutter 앱 (lib/, test/, tool/, android/, windows/, web/)
  lib/app/           앱 시작, 테마, 화면 이동, 상태 제공, 동기화 실행
  lib/core/          날짜, 형식, 창 너비 등급
  lib/domain/        열거형, 기본 분류, 월 기간, 월 집계
  lib/features/      화면: shell, home, transactions, input, stats, settings
  lib/ai/            입력 해석: 순서(input_interpreter), 규칙(text/), 모델(llm/)
  lib/data/          로컬 DB(db/), 저장소(repositories/), 동기화(sync/), 서버 연결(server/)
  tool/              웹 빌드 준비, 라이선스 검사, 해석 평가(llm_eval)
supabase/            서버 SQL과 시험, 동기화 규약 (supabase/README.md)
eval/                골든 세트 · 홀드아웃 표본, 생성 스크립트, 실측 기록
docs/                설계서(SPEC.md), 화면
.github/workflows/   시험, 서버 SQL 검증, Windows · Android · 웹 빌드, 웹 배포
```

설계 전체와 파일 구조는 [docs/SPEC.md](docs/SPEC.md)에 있다.

## 개발

Flutter 3.50.0(stable)을 쓴다.

```bash
cd app
flutter pub get
flutter test                              # Linux에서는 libsqlite3-dev가 필요하다
dart run tool/check_licenses.dart         # 의존성 라이선스 검사
```

웹으로 실행하려면 SQLite WebAssembly와 웹 워커를 먼저 준비한다.

```bash
cd app
dart run tool/prepare_web_assets.dart
flutter run -d chrome
```

배포용 웹 빌드는 엔진 파일을 앱과 함께 올린다. 앱이 다른 서버에 접속하지 않게 하기 위해서다.

```bash
cd app
flutter build web --release --no-web-resources-cdn
```

테이블을 고치면 생성 코드를 다시 만든다.

```bash
cd app
dart run build_runner build
```

푸시할 때마다 CI(`.github/workflows/ci.yml`)가 시험, 서버 SQL 검증, 웹 · Android · Windows 빌드를 돌린다. 실행 결과 페이지의 Artifacts에서 시험용 APK(`gagyebu-android-arm64`, 디버그 키 서명)와 Windows 실행 폴더(`gagyebu-windows-x64`)를 내려받을 수 있다.

서버(Supabase) 주소와 공개 키를 넣어 빌드하면 로그인과 동기화가 켜진다. 넣지 않으면 기기 안에서만 동작한다. 두 값은 공개해도 되는 값이고, service_role 키와 DB 비밀번호는 앱이나 저장소에 넣지 않는다.

```bash
cd app
flutter run -d chrome --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxx
```

CI는 저장소 변수 `SUPABASE_URL`과 `SUPABASE_PUBLISHABLE_KEY`를 읽어 같은 방식으로 빌드한다. 서버 쪽 준비(마이그레이션 적용, Google 로그인 설정)는 `supabase/README.md`에 있다.

서버 SQL은 임시 PostgreSQL 16 클러스터에서 시험한다.

```bash
supabase/tests/run_local.sh
```

문자 형식 표본을 더하거나 고치면 골든 세트를 다시 만든다.

```bash
python3 eval/tool/build_paste_golden.py
```

규칙과 모델이 처음 보는 표본을 얼마나 읽는지 잰다. 모델을 쓰는 모드는 `eval/README.md`를 본다.

```bash
cd app
dart run tool/llm_eval.dart --mode=rules --set=holdout
```

## 지키는 것

- 붙여넣은 원문과 이미지는 기기 밖으로 나가지 않는다. 서버에는 사용자가 확인해 저장한 거래와 설정만 올라간다.
- AI가 읽은 거래는 검토 카드에서 확인해야 저장된다. 금액과 날짜 계산은 모델이 아니라 규칙 코드가 한다. 모델은 규칙이 뽑은 후보 가운데에서 고르기만 한다.
- 모든 읽기와 쓰기는 기기의 로컬 DB에서 먼저 일어난다. 서버가 멈춰도 앱은 계속 쓸 수 있다.
- 웹 앱의 데이터는 그 브라우저 안에만 있다. 공유 워커가 없는 브라우저(Samsung Internet, 앱 안의 웹뷰 등)는 탭마다 DB 사본을 따로 들기 때문에, 나중에 연 탭만 쓰이고 먼저 열려 있던 탭은 멈춘다. 두 탭이 서로의 저장 내용을 덮어쓰는 것을 막기 위해서다.
- 라이브러리와 모델은 소스 공개 의무가 없는 허용형 라이선스만 쓴다(MIT · BSD · Apache-2.0 등). `tool/check_licenses.dart`가 CI에서 확인한다.
- 서버 테이블, 기기 테이블, 동기화 컬럼 목록은 같은 컬럼을 가져야 한다. `test/data/schema_contract_test.dart`가 어긋남을 잡는다.
