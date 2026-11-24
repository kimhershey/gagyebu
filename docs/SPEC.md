# 가계부 — 소프트웨어 설계서

기준: 2026-11-24. 이 문서가 설계의 원본이다. 구현된 것과 앞으로 만들 것을 함께 적고, 장마다 **[구현됨]** · **[예정]** 으로 가른다. 선택의 근거와 조사 내용(기술 비교, 모델 비교, 다른 가계부 앱 조사, 라이선스 검토)은 [소프트웨어 상세 설계안(계획 · 근거)](https://claude.ai/artifact/R7AHGE5GLftfDZYvz3TCKD)에 있다. 두 문서가 다르면 이 문서를 따른다.

---

## 1. 범위와 원칙

### 1.1 무엇을 만드는가

문자와 문장으로 적는 가계부다. 결제 문자를 붙여넣거나 한 줄로 적으면 기기 안에서 해석해 거래 초안을 만들고, 사용자가 확인하면 저장한다. 로그인한 계정의 가계부를 여러 기기가 함께 본다.

| 대상 | 방식 | 기기 안의 AI |
| --- | --- | --- |
| Windows, Android | Flutter 앱(같은 코드) | 규칙 + 소형 LLM, Windows는 이미지 입력(VLM)까지 |
| 웹, iPhone · iPad · Mac | Flutter 웹 앱(GitHub Pages) | 규칙만 |
| Apple 네이티브 앱 | v1 이후 | — |

### 1.2 지키는 원칙

1. **원문은 기기 밖으로 나가지 않는다.** 붙여넣은 글과 이미지는 서버에도, 기기의 저장소에도 남기지 않는다. 서버에 올라가는 것은 사용자가 확인해 저장한 거래와 설정뿐이다.
2. **AI가 읽은 것은 초안이다.** 검토함에서 승인해야 저장된다. 저장한 묶음은 되돌릴 수 있다.
3. **숫자는 규칙과 SQL이 만든다.** 모델은 후보 가운데 고르거나 문장으로 옮기기만 한다.
4. **모든 읽기와 쓰기는 로컬 DB에서 먼저 일어난다.** 서버에 닿지 않아도 로그인한 기기는 그대로 쓰인다.
5. **소스 공개 의무가 없는 허용형 라이선스만 쓴다**(MIT, BSD, Apache-2.0, ISC, Zlib, OFL, 퍼블릭 도메인). MPL · LGPL · GPL은 쓰지 않는다. CI가 검사한다.
6. **비밀값은 저장소와 앱에 넣지 않는다.** 앱에 들어가는 것은 서버 주소와 publishable 키뿐이다.

### 1.3 v1의 범위

| 넣는다 | 뺀다(v1 이후) |
| --- | --- |
| 로그인(이메일 · Google), 동기화, 거래 · 분류 · 자산, 내역(목록 · 달력 · 필터), 입력창과 검토함, 작업 기록과 되돌리기, 명령창, 테마, 홈 · 통계 · 월별 요약, 예산, 카드 결제 처리, 반복 · 할부, 자연어 조회, 내보내기 · 가져오기, 앱 잠금, 공유 수신(Android), 기기 내 모델과 모델 관리, 이미지 입력(Windows), 설치 파일과 릴리스 | 결제 알림 담기, 공유 가계부, 영수증 촬영 · 음성 입력, Kakao 로그인, 종단간 암호화, 다중 통화 집계, PDF 내보내기, 브라우저 안의 LLM, Apple 네이티브 앱, 스토어 등록 |

지원 환경: Android 10 이상(기기 내 LLM은 RAM 6GB 이상), Windows 10 · 11(RAM 8GB 이상), 웹은 Chrome · Edge · Firefox 최신 2개 버전과 Safari 15.6 이상. 통화는 원(KRW)으로 집계하고, 외화 결제는 원래 금액과 통화를 함께 적는다.

---

## 2. 구조

```
┌──────────────── 기기(앱 · 브라우저) ──────────────────┐
│  화면(features) ── Riverpod ── 저장소(repositories)    │
│      │                              │                  │
│  입력 해석(ai)                   로컬 DB(SQLite)        │
│   규칙 → (모르는 형식만) LLM        │  └ 대기열(outbox) │
│   이미지 → VLM(Windows)          동기화 엔진(sync)      │
└─────────────────────────────────────┬─────────────────┘
                                      │ 로그인한 계정
                        ┌─────────────▼──────────────┐
                        │ Supabase(서울)             │
                        │  Auth · PostgreSQL · 신호  │
                        │  sync_push · sync_pull     │
                        └────────────────────────────┘
```

### 2.1 층과 의존 방향

| 층 | 폴더 | 하는 일 | 볼 수 있는 층 |
| --- | --- | --- | --- |
| 앱 | `lib/app` | 시작, 화면 이동, 상태 제공자, 테마, 동기화 실행 | 전부 |
| 화면 | `lib/features` | 화면과 화면의 상태 | 앱의 제공자, 저장소, 도메인, 입력 해석의 결과 타입 |
| 입력 해석 | `lib/ai` | 글 · 이미지를 거래 초안으로 | 도메인, core. **Flutter에 의존하지 않는다** |
| 플랫폼 | `lib/platform` | 딥링크, 공유 수신, 업데이트 확인, 보안 저장소 | core |
| 데이터 | `lib/data` | 로컬 DB, 저장소, 동기화, 서버 연결, 기기 설정 | 도메인, core |
| 도메인 | `lib/domain`, `lib/core` | 날짜, 월 기간, 집계, 열거형, 형식 | 서로만 |

- 화면은 DB를 직접 열지 않는다. 읽기와 쓰기는 저장소를 거친다. 저장소가 돌려주는 행 타입(`TxRow`, `AccountRow` 등)은 화면이 그대로 쓴다.
- 서버와의 연결은 인터페이스(`AuthService`, `SyncGateway`) 뒤에 둔다. 시험에서는 가짜로 바꿔 끼운다.
- 모델 실행도 인터페이스(`LlmEngine`, `VisionEngine`) 뒤에 둔다.

### 2.2 앱이 시작하는 순서 [구현됨]

`lib/app/bootstrap.dart`

1. 기기 설정(테마)을 읽는다. 첫 화면부터 고른 테마로 그린다.
2. 로컬 DB를 연다. 웹에서 공유 워커가 없는 브라우저면 탭 잠금을 먼저 잡는다(나중에 연 탭만 쓰인다).
3. 가계부가 없으면 만든다(`ensureLocalLedger`).
4. 서버에 연결한다. 저장된 세션이 있으면 되살리고, 주소의 로그인 코드를 처리한다.
5. 로그인하지 않았으면 안내 화면(`/welcome`)으로, 했으면 가계부로 간다.
6. 로그인한 계정의 가계부에 기기를 맞추고(첫 로그인이면 기기의 내용을 옮긴다) 동기화를 시작한다. 가계부가 바뀌면 앱을 새 가계부로 다시 연다.

### 2.3 기기가 밖과 주고받는 것

| 연결 | 대상 | 보내는 내용 |
| --- | --- | --- |
| 로그인 | Supabase Auth, Google 로그인 화면 | 계정 인증 정보 |
| 동기화 | Supabase(서울) | 확인해 저장한 거래와 설정 |
| 웹 앱 불러오기 | GitHub Pages | 없음 |
| 모델 내려받기(Windows · Android) | Hugging Face | 없음 |
| 모델 카탈로그, 버전 확인, 설치 파일 | GitHub 공개 저장소의 파일과 Releases | 없음 |

---

## 3. 데이터

### 3.1 로컬 DB

SQLite(Drift). Windows · Android는 앱 폴더의 파일, 웹은 SQLite WebAssembly + 브라우저 저장소(OPFS, 없으면 IndexedDB). 외래 키 제약은 걸지 않는다(동기화로 받은 행의 순서를 보장할 수 없다). 시각은 UTC ISO 8601 문자열, 날짜는 `YYYY-MM-DD`, 금액은 원 단위 정수다.

**동기화하는 표 9개** [구현됨] — 서버와 같은 모양이다. 모든 표가 아래 공통 열을 갖는다.

| 공통 열 | 뜻 |
| --- | --- |
| `id` | UUIDv7(기기가 만든다) |
| `ledger_id` | 가계부(`ledgers`에는 없다) |
| `version` | 서버가 올리는 판 번호. 0이면 서버에 올라간 적이 없다 |
| `server_seq` | 서버가 매긴 일련번호 |
| `client_updated_at` | 기기에서 마지막으로 고친 때 |
| `created_at`, `updated_at`, `deleted_at` | 삭제는 `deleted_at`에 표시만 한다 |

| 표 | 고유 열 |
| --- | --- |
| `ledgers` | `owner_id`, `name`, `currency` |
| `profiles` | `display_name`, `month_start_day`(1–28), `default_account_id` |
| `accounts` | `name`, `kind`(cash · bank · credit_card · check_card · pay · other), `institution`, `match_hints`(JSON 배열), `opening_balance`, `billing_day`, `payment_account_id`, `sort_order` |
| `categories` | `kind`(expense · income), `name`, `parent_id`, `icon`, `sort_order` |
| `transactions` | `type`(expense · income · transfer), `occurred_on`, `occurred_time`, `amount`, `currency`, `original_amount`, `account_id`, `to_account_id`, `sender`, `receiver`, `category_id`, `memo`, `tags`, `installment_months`, `balance_after`, `canceled_at`, `source`(manual · nl · paste · image · share · import · recurring), `ai_model`, `status`(confirmed · needs_review), `dedup_key` |
| `budgets` | `month`(`YYYY-MM`), `category_id`(null이면 전체 예산), `amount` |
| `recurring_rules` | `template`(JSON), `frequency`(weekly · monthly · yearly), `interval_count`, `next_run_on`, `end_on`, `auto_post`, `is_active` |
| `category_rules` | `pattern`, `category_id`, `hit_count` |
| `monthly_summaries` | `month`, `stats`(JSON), `narrative`, `data_hash`, `ai_model` |

**기기에만 있는 표**

| 표 | 열 | 상태 |
| --- | --- | --- |
| `outbox` | `seq`, `ledger_id`, `target_table`, `row_id`, `op`(upsert · delete), `base_version`, `client_updated_at`, `attempts`, `last_error`. (표, 행)마다 한 줄 | 구현됨 |
| `sync_state` | `key`, `value` — `device_id`, `cursor:<가계부>`, `last_pull_at:<가계부>`, `pending_batch:<가계부>`, `owner_user_id` | 구현됨 |
| `sync_conflicts` | `seq`, `ledger_id`, `target_table`, `row_id`, `loser`(JSON), `loser_side`(local · remote), `detected_at` | 구현됨 |
| `input_batches` | `id`, `ledger_id`, `created_at`, `source`, `item_count`, `undone_at` | **v2** |
| `input_batch_items` | `batch_id`, `tx_id`, `kind`(created · canceled), `stamp`(저장했을 때 그 거래의 `client_updated_at`). 키는 (`batch_id`, `tx_id`) | **v2** |
| `model_files` | `id`(카탈로그의 ID), `kind`(text · vision · mmproj), `file_name`, `path`, `size_bytes`, `downloaded_bytes`, `sha256`, `status`(downloading · ready · failed), `updated_at` | **v2** |

옛 설계의 `parse_jobs`(해석 이력과 원문 보관)는 만들지 않는다. 원칙 1과 어긋난다.

**스키마 판과 마이그레이션**

| 판 | 내용 |
| --- | --- |
| 1 | 동기화 표 9개 + `outbox` · `sync_state` · `sync_conflicts` |
| 2 | `input_batches` · `input_batch_items` · `model_files` 추가. 있던 표는 바꾸지 않는다 |

`onUpgrade`는 판마다 한 단계씩 올린다. 판 1로 만든 DB를 판 2 앱으로 열어 내용이 남는지 시험으로 확인한다(`test/data/migration_test.dart`).

**기기 설정** — DB가 아니라 `shared_preferences`에 둔다(DB를 열기 전에 읽어야 하고, 계정을 바꿔도 남아야 한다).

| 키 | 값 |
| --- | --- |
| `theme.tone` | system · quiet · tool · ledger |
| `theme.brightness` | system · light · dark |
| `lock.pin` | 잠금 번호의 솔트와 해시(없으면 잠금 꺼짐) |
| `lock.biometric` | true · false |
| `model.endpoint` | 사용자가 띄운 로컬 엔진의 주소(Windows, 선택) |
| `onboarding.done` | true면 첫 실행 안내를 보이지 않는다 |

### 3.2 서버 [구현됨]

Supabase(PostgreSQL). `supabase/migrations/0001–0004`. **v1에서 서버 스키마는 바꾸지 않는다.**

- 표: 위 9개 + `sync_batches`(받은 묶음의 결과를 90일 보관). 전역 시퀀스 `server_seq` 하나로 모든 변경에 번호를 매긴다.
- 제약: 금액 · 날짜 · 종류의 값 범위, 이체면 `to_account_id` 필수, 같은 가계부 안의 행만 가리킬 수 있다. 같은 달 · 같은 분류의 예산처럼 자연 키의 유일성은 서버가 지키지 않는다(7.11의 규칙으로 기기가 고른다).
- 권한: 모든 표에 행 단위 보안. 로그인한 사용자는 자기 가계부의 행을 **읽을 수만** 있다. 쓰기는 `sync_push`로만 한다.
- 함수: `sync_push`, `sync_pull`, `delete_my_account`(로그인한 사용자가 실행), `purge_tombstones`(서비스 역할만), 가입 트리거 `handle_new_user`(가계부 · 프로필 · 현금 자산 · 기본 분류 16개를 만든다).

---

## 4. 동기화 · 인증

### 4.1 올리기와 받기 [구현됨]

`lib/data/sync/`. 서버 쪽 규약과 JSON 예시는 `supabase/README.md`에 있다.

- **쓰기**: 저장소는 행을 쓰면서 같은 트랜잭션에서 `outbox`에 올린다. 같은 행을 또 고치면 한 줄로 합친다.
- **올리기**: 대기열에서 200건씩 묶어 `sync_push(가계부, 기기, 묶음 ID, 변경들)`로 보낸다. 보내기 전에 묶음을 `sync_state`에 적어 두어, 답을 못 받았으면 같은 ID로 다시 보낸다. 서버는 같은 묶음을 한 번만 적용한다.
- **받기**: `sync_pull(가계부, 커서, 500)`으로 커서 뒤의 변경을 받아 쓴다. 대기열에 있는 행은 건너뛴다. 80일 넘게 받지 않았으면 처음부터 다시 받고 서버에 없는 행을 지운다.
- **충돌**: 행 단위로 나중에 고친 쪽이 이긴다(서버가 판정). 진 쪽은 `sync_conflicts`에 남긴다.
- **언제**: 로그인 직후, 기기에서 바꾼 뒤 2초, 1분마다, "지금 동기화", 그리고 실시간 신호를 받았을 때(4.4).

### 4.2 로그인 [구현됨]

- Supabase Auth. **이메일 · 비밀번호**(모든 플랫폼)와 **Google**(PKCE, 웹. 앱은 4.3).
- **로그인해야 쓴다.** 로그인하지 않은 동안에는 안내 화면(`/welcome`)에만 머문다. 고를 것은 "계정 만들기"와 "로그인" 둘이고, 두 화면 모두 Google 로그인과 이메일 · 비밀번호 입력을 함께 보여 준다. 로그아웃하면 안내 화면으로 돌아간다. 서버 주소를 넣지 않은 빌드(개발용)에는 로그인이 없다.
- 비밀번호를 잊으면 로그인 화면에서 메일을 보내고, 메일의 링크로 들어오면 새 비밀번호를 정한 뒤에 가계부가 열린다.
- 지금 서버는 가입할 때 메일 확인을 받지 않는다(Confirm email 꺼짐). 비밀번호를 다시 정하는 메일을 여러 사람에게 보내려면 메일 서버(SMTP)를 연결해야 한다.
- **첫 로그인**: 기기에 적어 둔 거래 · 자산 · 분류 · 월 시작일을 계정의 가계부로 옮긴다. 이름과 종류가 같은 기본 분류 · 자산은 서버 것을 쓴다(`data/sync/ledger_adoption.dart`).
- **다른 계정이 쓰던 기기**: 섞지 않는다. 설정 화면으로 보내 "지우고 받기"를 묻는다.
- **로그아웃**: 이 기기에서만 한다. 기기의 가계부와 대기열은 지우지 않는다. 같은 계정으로 다시 로그인하면 이어서 올린다.

인터페이스(`lib/data/server/server_connection.dart`): `AuthService`(현재 사용자, 로그인 · 가입 · 로그아웃, 비밀번호 다시 정하기), `SyncGateway`(`push`, `pull`), `ServerConnection`(둘과 `ledgerIdOf`). 실패는 `AuthFailure(reason)`로 구분한다.

### 4.3 Windows · Android 앱에서의 Google 로그인 [예정]

- 앱이 기기의 브라우저로 Google 로그인 화면을 열고, 로그인이 끝나면 주소 `io.github.kimhershey.gagyebu://login-callback`으로 앱에 돌아온다. Android는 매니페스트의 인텐트 필터, Windows는 설치할 때 등록하는 URL 스킴으로 받는다.
- Supabase의 Redirect URLs에 이 주소를 넣어야 한다(사용자가 설정).
- 세션은 Android에서는 OS 보안 저장소에 둔다(`flutter_secure_storage`). Windows는 앱 폴더의 파일을 쓴다(v1).
- 끝 기준: `AuthService.googleAvailable`이 세 플랫폼에서 true이고, 돌아온 주소를 세션으로 바꾸는 경로에 시험이 있다. 실제 왕복은 기기에서 확인한다.

### 4.4 실시간 신호 [예정]

- 서버는 변경이 적용될 때마다 채널 `ledger:<가계부 ID>`로 `changed` 신호를 보낸다(이미 구현됨).
- 기기는 로그인해 가계부가 맞춰지면 이 채널을 `private: true`로 구독한다. 신호를 받으면 0.5초 모았다가 받기를 한 번 한다. 자기가 올린 변경의 신호도 오지만 받을 것이 없으므로 해가 없다.
- 구독이 끊기면 라이브러리가 다시 붙는다. 1분 주기의 받기는 그대로 둔다(신호를 놓쳐도 1분 안에 맞춰진다).
- 인터페이스: `ServerConnection`에 `Stream<void> Function(String ledgerId) changes`를 더한다.
- 끝 기준: 가짜 서버가 신호를 내면 1초 안에 받기가 도는 시험. 실서버에서 두 기기가 5초 안에 맞춰지는지는 기기에서 확인한다.

### 4.5 탈퇴 [예정]

- 설정 → 계정 → "계정 삭제". 무엇이 지워지는지 보여 주고, 이메일을 그대로 적어야 단추가 켜진다.
- `delete_my_account()`를 부른다. 성공하면 기기의 가계부 · 대기열 · 작업 기록을 지우고 로그아웃한다. 대기열에 남은 변경은 버린다(올릴 곳이 없다).
- 끝 기준: 가짜 서버로 흐름 시험. 실서버 동작은 시험 계정으로 이미 확인했다.

### 4.6 충돌 기록 [예정]

- 설정 → "동기화 충돌". 진 쪽의 값과 이긴 쪽의 값을 나란히 보여 준다.
- "되살리기"는 진 값으로 그 행을 다시 쓴다(새 변경으로 올라간다). 삭제된 행을 되살리는 것도 같다.
- 30일 지난 기록과 200건을 넘는 오래된 기록은 앱을 켤 때 지운다.

---

## 5. 입력 해석

`lib/ai`. Flutter에 의존하지 않아 `dart run`으로 평가할 수 있다(`app/tool/llm_eval.dart`, 기록은 `eval/README.md`).

### 5.1 순서 [구현됨]

`interpretInput`(`lib/ai/input_interpreter.dart`)

1. **형식 규칙**: 표기를 정리하고 문자 한 건씩 나눈 뒤, 안내문(인증번호 · 광고 · 예정 · 실패 · 명세서)을 거르고, 아는 형식 32가지(은행 문자 9, 카드 문자 13, 앱 알림 9, 항목형 카드 문자 1)를 토큰 단위로 맞춘다.
2. **한 줄 문장**: 금융사가 보낸 글로 보이지 않는 한 줄은 규칙이 날짜 · 금액 · 방향 · 결제수단을 읽는다. 남은 말에서는 무엇에 쓴 돈인지만 상대방으로 두고('김밥천국'), 끼니 · 수량은 메모로 보내고, '먹음' · '결제' 같은 말은 버린다.
3. **모르는 형식**: 기기 안의 LLM이 있으면 넘긴다(5.2). 없으면 "읽지 못함"으로 남기고 직접 입력을 권한다.
4. 결과는 거래 초안(`ParsedTransaction`), 거래 아님(`NonTransactionItem`), 읽지 못함(`UnrecognizedItem`) 가운데 하나다.

이 순서는 실측으로 정했다. 처음 보는 형식의 문자 20건에서 모든 항목이 맞은 초안은 규칙만 0건, Qwen3.5-2B를 붙이면 13건(건당 4.9초)이었고, 사람이 쓴 문장 20건은 규칙이 17건으로 모델(15건)보다 정확했다.

### 5.2 모델에 묻는 방식 [구현됨]

`lib/ai/llm/`. 프롬프트 판 v5.

- 규칙이 원문에서 **후보**를 뽑는다: 날짜, 금액(잔액 · 누적은 역할을 붙여 구분), 이름(날짜 · 금액 · 계좌번호 · 명의자 · 금융사 이름 · 거래 낱말을 지운 나머지).
- 모델은 `{"tx":[{"d","a","io","who","memo","cat"}],"real"}` 꼴로 답한다. 각 값은 후보 가운데 하나여야 하고, 문법(GBNF)이나 JSON 스키마로 강제한다. `real`(거래인지)은 맨 끝에 둔다.
- 방향이 낱말로 정해지면 묻지 않는다. 취소 · 환불은 지출의 취소로 고정한다. 금액 후보가 없으면(해외 결제) 금액을 비운다.
- 시각, 잔액, 할부, 취소 여부, 자산은 규칙이 원문에서 읽어 붙인다.
- 답이 후보 밖이거나 잘리면 한 번 다시 묻고, 또 실패하면 "읽지 못함"이다.

```dart
abstract interface class LlmEngine {
  String get modelName;
  Future<String> generateJson({
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 512,
  });
}
```

### 5.3 검토에서 붙이는 것 [구현됨]

- 자산 매칭: 초안의 카드 · 계좌 표기를 자산의 `match_hints`와 맞춘다. 못 찾으면 기본 자산.
- 분류: 사용자가 고쳤던 상대방의 분류(`category_rules`)가 먼저, 다음이 낱말 사전(`category_hints.dart`). 상대방만으로 먼저 짐작하고 안 되면 메모까지 본다.
- 중복: 날짜 · 금액 · 상대방이 같은 거래가 있으면 경고한다(`dedup_key`).
- 취소: 승인취소면 90일 안의 원 거래를 찾아 그 거래의 취소를 제안한다.
- 경고 7종: 연도 추정, 날짜를 오늘로 둠, 원화 금액 필요, 카드대금일 수 있음, 단위 없는 금액, 상대방 없음, 방향 불일치.

### 5.4 기기 안의 모델 [예정]

| 항목 | 정한 것 |
| --- | --- |
| 런타임 | `llama.cpp` + `llamadart`(MIT). 버전을 고정한다. Android는 CPU, Windows는 Vulkan(실패하면 CPU) |
| 대비책 | 사용자가 띄운 OpenAI 호환 서버에 연결(`OpenAiCompatibleEngine`, 이미 있음). 설정에 주소를 적는다(Windows) |
| 텍스트 모델 | Qwen3.5-2B Q4_K_M(1.28GB, Apache-2.0). 생각 모드를 끈다 |
| 등급 | 실행 중에 읽은 기기 메모리로 정한다 |
| 웹 | 모델이 없다. 규칙과 직접 입력 |

| 기기 | 메모리 | 텍스트 | 이미지(Windows) |
| --- | --- | --- | --- |
| 휴대폰 | 6GB 이상 | Qwen3.5-2B | — |
| 휴대폰 | 6GB 미만 | 없음(규칙만) | — |
| PC | 8–15GB | Qwen3.5-2B | Qwen3.5-2B + mmproj |
| PC | 16GB 이상 | Qwen3.5-2B | Qwen3.5-4B + mmproj |

**카탈로그** — 저장소의 `catalog/models.json`. 앱은 GitHub의 원본 주소에서 읽고, 못 읽으면 앱에 들어 있는 사본을 쓴다.

```json
{
  "version": 1,
  "models": [
    {
      "id": "qwen3.5-2b-q4_k_m",
      "kind": "text",
      "name": "Qwen3.5-2B",
      "license": "Apache-2.0",
      "url": "https://huggingface.co/…/….gguf",
      "size_bytes": 1374389534,
      "sha256": "…",
      "min_memory_gb": 6,
      "platforms": ["android", "windows"],
      "mmproj": null
    }
  ]
}
```

**모델 관리**(`lib/ai/llm/model_manager.dart`, 화면은 설정 → "AI 모델")

- 기기 사양을 읽어 맞는 모델을 권한다. 사용자가 "내려받기"를 눌러야 받는다. 모바일 데이터면 크기를 알리고 한 번 더 묻는다.
- 이어받기(HTTP Range), 끝나면 SHA-256 확인. 틀리면 지우고 실패로 둔다. 상태는 `model_files`에 적는다.
- 파일은 앱 지원 폴더의 `models/`에 둔다. 저장 공간이 모자라면 받기 전에 알린다. 모델을 바꾸면 옛 파일을 지울지 묻는다.
- 모델은 처음 쓸 때 메모리에 올리고 5분 동안 쓰지 않으면 내린다. Android가 앱을 내렸다가 올리면 다시 올린다.
- 추론은 별도 격리 영역(isolate)에서 돌고 취소할 수 있다. 검토함은 건마다 진행을 보여 준다.
- 끝 기준: 가짜 HTTP로 이어받기 · 해시 불일치 · 공간 부족 시험, 등급 고르기 시험, 엔진이 없을 때 규칙만으로 동작하는 시험. 실제 추론 속도와 메모리는 기기에서 확인한다.

### 5.5 이미지 입력 [예정, Windows]

```dart
abstract interface class VisionEngine {
  String get modelName;
  Future<String> generateJsonFromImage({
    required Uint8List image,
    required String system,
    required String user,
    required Map<String, Object?> schema,
    String? grammar,
    int maxTokens = 1024,
  });
}
```

- 이미지를 창에 끌어놓거나, 붙여넣거나(Ctrl+V), 파일을 고른다. 여러 장은 대기열에 쌓아 한 장씩 처리한다.
- VLM이 이미지에서 거래 배열을 뽑는다: `{"rows":[{"d","t","a","io","who","bal"}]}`. 금액 후보가 없으므로 다른 방법으로 검산한다 — 거래내역 화면은 잔액이 이어지는지, 영수증은 품목 합이 총액과 맞는지. 검산에 실패한 행은 "확인 필요"로 표시한다.
- 화면(`/image-input`): 왼쪽에 원본, 오른쪽에 뽑은 표. 행마다 고치거나 뺀다. "검토함으로 보내기"를 누르면 입력창에서 온 초안과 같은 검토함으로 간다(출처 `image`).
- 이미지는 메모리에서만 다루고 저장하지 않는다.
- 모델이 없거나 메모리가 8GB 미만이면 메뉴를 숨긴다.
- 끝 기준: 가짜 엔진으로 추출 → 검산 → 검토함 전달 시험. 실제 정확도(목표: 금액 일치 95% 이상)와 시간은 기기에서 잰다.

### 5.6 평가 기준

| 입력 | 표본 | 목표 | 지금 |
| --- | --- | --- | --- |
| 결제 문자 · 은행 앱 복사 | 300건 이상 | 금액 · 방향 99%, 날짜 98% | 다듬는 표본 39건은 모두 맞음. 처음 보는 형식 20건은 모든 항목 13–14건 |
| 한 줄 문장 | 200건 이상 | 금액 98%, 날짜 95% | 처음 보는 문장 20건 중 17건 |
| 이미지 | 100장 이상 | 금액 일치 95%, 빠뜨린 행 5% 이하 | 재지 않음 |
| 시간 | — | 휴대폰 문자 1건 10–30초, PC 이미지 1장 20–90초 | 4코어 CPU에서 문자 1건 4.9초 |

목표에는 아직 못 미친다. 그래서 모델이 읽은 것도 검토함을 거친다.

---

## 6. 화면

시안: https://claude.ai/artifact/1KaeZwtcFM2tBt1EC2rNDT

### 6.1 테마 [예정 → 기반에서 구현]

설정에서 톤을 고른다: **시스템에 맞춤**(기본) · **금융** · **도구** · **가계부**. "시스템에 맞춤"은 시스템이 밝으면 금융 · 밝게, 어두우면 도구 · 어둡게다. 톤을 직접 고르면 밝기(시스템 · 밝게 · 어둡게)도 고른다. 설정은 기기에만 저장하고(3.1) 앱이 뜨기 전에 읽는다.

색 값은 `docs/ui-palettes.json`이 원본이고 `lib/app/theme/palettes.dart`가 같은 값을 든다(시험이 둘을 대조한다).

| 팔레트 | 바탕 | 면 | 글자 | 보조 글자 | 강조 | 수입 | 지출 | 확인 필요 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 금융 · 밝게 | #FFFFFF | #F4F6F9 | #191F28 | #5C6773 | #1E3A8A | #1B64DA | #D22B2B | #9A5B00 |
| 금융 · 어둡게 | #101318 | #181C23 | #EEF1F5 | #A3ACB8 | #8FB0FF | #7FB2FF | #FF8A80 | #F2B75C |
| 도구 · 밝게 | #FAFAFB | #FFFFFF | #1B1F24 | #59616C | #3451B2 | #0B62C4 | #C9302C | #8F5600 |
| 도구 · 어둡게 | #0E1014 | #15181E | #E6E8EC | #9AA3B2 | #7AA2F7 | #6CB6FF | #FF7B72 | #E3B341 |
| 가계부 · 밝게 | #FAF6EF | #F3ECDF | #33291F | #6B5C4B | #9C4A2A | #1F6680 | #B03A26 | #855200 |
| 가계부 · 어둡게 | #1C1814 | #26211B | #F1E9DD | #B8AA97 | #E6A07E | #7CC0D8 | #F09480 | #E8B866 |

| | 금융 | 도구 | 가계부 |
| --- | --- | --- | --- |
| 모서리 | 16 | 8 | 12 |
| 줄 높이 | 52 | 40 | 48 |
| 큰 금액 글자 | 34 | 28 | 32 |
| 면의 테두리 | 없음 | 1px | 1px |

규칙:

- 금액에는 항상 +/− 부호를 붙인다. 색만으로 구분하지 않는다. 이체에는 부호를 붙이지 않는다.
- 지출색(`expense`)과 경고색(`warn`)을 나눈다. 수입색은 강조색과 구별된다.
- 글자 대비는 본문 · 금액 모두 4.5 이상(여섯 팔레트 모두 확인함).
- 금액은 고정폭 숫자로 쓴다(Pretendard의 tnum). 글꼴 굵기는 400과 600만 쓴다.
- 촘촘한 톤에서도 터치 기기의 누름 영역은 48dp를 지킨다.
- 색은 팔레트마다 직접 정한다(`ColorScheme.fromSeed`를 쓰지 않는다).
- **분류 색**: 팔레트의 12색을 분류의 순서(`sort_order`로 정렬한 자리)대로 돌려 쓴다. 열을 더하지 않는다. **분류 아이콘**: `categories.icon`에 이름을 적고 앱에 든 Material Icons로 그린다. 비어 있으면 기본 분류 이름에 맞는 아이콘, 그것도 없으면 꼬리표 아이콘. 이모지는 쓰지 않는다.

화면 코드는 색과 치수를 `Theme.of(context).colorScheme`과 `context.tokens`(`AppTokens`)에서만 읽는다. 색 값을 화면에 직접 적지 않는다.

### 6.2 뼈대 [예정 → 기반에서 구현]

| 너비 | 탐색 | 입력창 | 검토함 |
| --- | --- | --- | --- |
| 휴대폰(600 미만) | 하단 탭 4개: 홈 · 내역 · 통계 · 설정 | 탭 바로 위. 평소 한 줄, 누르면 넓어진다 | 전체 화면(`/review`) |
| 태블릿(600–839) | 레일 | 내용 위쪽 | 오른쪽에서 나오는 400dp 칸 |
| PC(840 이상) | 옆 메뉴: 홈 · 내역 · 통계 · 자산 · 예산 · 설정 | 위쪽 명령창(Ctrl/⌘+K) | 1200 이상은 오른쪽에 고정, 그 아래는 겹쳐서 |

- 탭이 아닌 화면(자산, 예산, 분류, 반복 거래, 작업 기록, 설정의 하위 화면)은 설정 탭에 속한다. 휴대폰에서는 설정의 "관리" 목록과 홈의 카드에서 들어간다.
- 화면마다 **빈 상태 · 불러오는 중 · 오류** 세 가지를 그린다. 오류는 예외 문구를 그대로 보이지 않고, 무엇이 안 됐고 어떻게 하면 되는지를 쓴다.
- 화면의 문장은 "…습니다" 체로 쓴다.

**주소**

| 주소 | 화면 | 맡는 곳 |
| --- | --- | --- |
| `/` · `/transactions` · `/stats` · `/settings` | 홈 · 내역 · 통계 · 설정 | 탭 |
| `/accounts` · `/categories` · `/budget` · `/recurring` | 자산 · 분류 · 예산 · 반복 거래 | 설정 탭 |
| `/history` | 작업 기록 | 설정 탭 |
| `/settings/account` · `/settings/data` · `/settings/lock` · `/settings/models` · `/settings/conflicts` | 계정 · 내보내기와 가져오기 · 앱 잠금 · AI 모델 · 동기화 충돌 | 설정 탭 |
| `/review` | 검토함(휴대폰) | 뼈대 밖 |
| `/query` | 조회 결과 | 뼈대 밖 |
| `/image-input` | 이미지 입력(Windows) | 뼈대 밖 |
| `/welcome` · `/welcome/login` · `/welcome/signup` · `/welcome/reset` · `/new-password` | 로그인 안내 | 뼈대 밖 |

### 6.3 입력창과 검토함

7.5–7.7에 적는다.

### 6.4 접근성

- 단추와 입력 칸에 이름표를 단다(아이콘만 있는 단추는 `tooltip`). 드롭다운과 막대 그림에는 값을 읽어 주는 설명을 단다.
- 글자 크기 200%에서 360×640, 412×915, 700×800, 1280×800 네 크기가 넘치지 않는다(시험이 확인한다).
- 키보드만으로 모든 화면에 갈 수 있고, 초점이 어디 있는지 보인다.

---

## 7. 기능별 명세

기능마다 **규칙 · 화면 · 데이터 · 인터페이스 · 끝 기준**을 적는다. "끝 기준"의 시험은 `app/test` 아래에 `lib`과 같은 구조로 둔다.

### 7.1 거래 기록 [구현됨, 보완 예정]

- 규칙: 수입 · 지출 · 이체. 날짜, 금액(양의 정수), 자산은 꼭 있어야 한다. 이체는 받는 자산이 꼭 있고 분류가 없다. 취소는 지우지 않고 `canceled_at`을 적는다(집계에서 빠진다). 부분 환불은 수입 거래로 따로 적는다.
- 화면: 내역에서 "새 거래" 또는 행을 누르면 편집 칸이 열린다(PC는 옆 칸, 휴대폰은 전체 화면). 종류 → 금액 → 날짜 → 자산 → 상대방 → 분류 → 메모 순서. 상대방을 적으면 예전에 고른 분류를 제안한다.
- 데이터: `transactions`. 지출의 상대방은 `receiver`, 수입은 `sender`에 적는다.
- 인터페이스: `LedgerRepository.addTransaction` · `updateTransaction` · `deleteTransaction` · `setCanceled`, 입력값은 `TransactionInput`(`status` 포함).
- 끝 기준: 있는 시험(`ledger_repository_test`, `responsive_shell_test`)이 통과한다.

### 7.2 자산과 분류 [일부 구현, 예정]

- 규칙
  - 자산: 추가 · 이름과 종류 수정 · 시작 잔액 수정 · 순서 바꾸기 · 삭제. 거래가 있는 자산은 지우지 못한다(먼저 거래를 옮기라고 안내한다). 잔액 = 시작 잔액 + 수입 − 지출 ± 이체(취소한 거래는 뺀다).
  - 카드 자산은 결제일(`billing_day`, 1–31)과 결제 계좌(`payment_account_id`)를 가진다(7.12).
  - 분류: 추가 · 이름 수정 · 아이콘 고르기 · 순서 바꾸기 · 삭제. 대분류 아래에 소분류를 한 단계 둔다. 대분류를 지우면 소분류는 대분류 없는 분류가 된다. 분류를 지우면 그 분류를 쓰던 거래는 "분류 없음"이 된다.
  - 문자의 카드 · 계좌 표기와 자산을 잇는 말(`match_hints`)을 자산마다 고친다.
- 화면: `/accounts` — 종류별로 묶은 목록, 자산마다 잔액. 누르면 편집. 길게 눌러 끌면 순서가 바뀐다(PC는 손잡이). `/categories` — 지출 · 수입 탭, 대분류와 소분류, 색 점과 아이콘. 아이콘은 40개쯤의 고정된 목록에서 고른다.
- 데이터: `accounts`, `categories`. 순서는 `sort_order`(10 간격, 끼워 넣을 때 가운데 값, 자리가 없으면 다시 매긴다).
- 인터페이스: `AccountRepository`(`updateAccount`, `reorderAccounts`), `CategoryRepository`(`updateCategory`, `reorderCategories`, `setParent`). 둘 다 `OutboxWriter`로 대기열에 올린다. 추가 · 삭제 · 조회는 `LedgerRepository`의 것을 쓴다.
- 끝 기준: 수정 · 순서 바꾸기가 대기열에 올라가는 저장소 시험, 화면 시험(추가 → 수정 → 순서 → 삭제), 소분류가 있는 대분류 삭제 시험.

### 7.3 내역 보기 [일부 구현, 예정]

- 규칙
  - 보기 두 가지: **목록**(날짜별 묶음, PC는 표)과 **달력**. 고른 달(월 시작일 반영)을 본다.
  - 달력: 한 달을 주 단위 격자로 그리고, 날짜 칸에 그날의 수입(+)과 지출(−) 합계를 적는다. 날짜를 누르면 아래(PC는 옆)에 그날의 거래가 뜬다.
  - 필터: 종류(수입 · 지출 · 이체), 분류, 자산, 금액 범위, "확인 필요만", "취소 포함". 검색어와 함께 건다. 건 필터는 칩으로 보이고 하나씩 지울 수 있다.
  - 일괄 수정(PC의 표): 여러 행을 골라 분류 바꾸기 · 자산 바꾸기 · 삭제. 행마다 한 건씩 저장한다(각각 대기열에 올라간다).
  - 확인 필요: `status = needs_review`인 거래에 경고색 표시를 달고, 거래를 열어 "확인함"을 누르거나 고쳐서 저장하면 `confirmed`가 된다.
- 화면: 위에 달 고르기 · 목록/달력 전환 · 검색 · 필터 단추. 빈 상태는 "이 달에는 내역이 없습니다"와 입력창을 가리키는 안내.
- 데이터: 있는 표로 충분하다. 날짜별 합계는 `MonthSummary`에 `dailyIncome`을 더한다.
- 인터페이스: `LedgerRepository.watchTransactions`에 필터 값(`TransactionFilter`)을 넘긴다. 화면의 상태는 `transactionFilterProvider`, `transactionViewModeProvider`.
- 끝 기준: 필터 조합의 저장소 시험, 달력 칸 합계 시험, 일괄 수정 시험, 네 화면 크기에서 넘치지 않는 시험.

### 7.4 한 줄 입력 · 붙여넣기 [구현됨]

5장에 적었다. 출처는 문장이면 `nl`, 붙여넣은 글이면 `paste`, 공유로 받은 글이면 `share`.

### 7.5 입력창 [예정]

- 규칙
  - 어느 화면에서나 보인다(6.2). 여러 줄 붙여넣기를 받는다. 최대 20,000자, 넘으면 알리고 자른다.
  - 보내기: PC는 Enter(줄바꿈은 Shift+Enter), 휴대폰은 보내기 단추. **한글을 조합하는 중의 Enter는 보내지 않는다.**
  - 보내면 해석해(5.1) 초안을 검토함에 넣는다. 한 건도 못 읽었으면 "읽지 못했습니다"와 함께 직접 입력(새 거래)을 권한다.
  - 조회로 보이는 문장(`looksLikeQuery`)은 조회 화면으로 보낸다(7.15).
  - 비어 있으면 예시 칩을 보여 준다: "결제 문자 붙여넣기"(클립보드를 읽어 채운다), "어제 점심 9천원"(예시를 채운다).
  - 공유로 받은 글(7.18)은 입력창에 채워 두고 사용자가 보낸다.
  - 모델이 도는 동안에는 진행(몇 건 가운데 몇 건)과 "그만" 단추를 보여 준다.
- 화면: `ComposerBar(placement)` — 휴대폰은 하단 탭 위, 태블릿은 내용 위, PC는 맨 위의 명령창. Windows에서 이미지 입력을 쓸 수 있으면 이미지 단추가 붙는다.
- 인터페이스: `composerControllerProvider`(글, 진행 상태, `submit()`, `fill(text)`), `incomingTextProvider`(밖에서 채워 넣을 글).
- 끝 기준: 한글 조합 중 Enter가 보내지 않는 시험, 붙여넣기 → 검토함 시험, 못 읽었을 때의 안내 시험, 세 배치의 화면 시험.

### 7.6 검토함 [예정] (제안 → 승인)

- 규칙
  - 초안 묶음을 한 번에 본다. 맨 위에 한 줄 요약: "6건 읽음 · 1건 확인 필요 · 안내문 2건 제외".
  - 건마다 **포함 · 고치기 · 제외**. 기본은 포함이고, 중복으로 보이는 건은 기본이 제외다.
  - 고칠 수 있는 것: 종류(지출 · 수입 · **이체**), 날짜, 금액, 상대방, 자산, 받는 자산(이체), 분류, 메모.
  - 경고가 있는 건(5.3)은 "확인 필요"로 표시한다. 사용자가 그 건을 고치면 표시가 풀린다. 표시가 남은 채 저장하면 거래에 `needs_review`가 붙는다.
  - 카드대금으로 보이는 출금은 이체(계좌 → 카드)로 제안한다(7.12).
  - "모두 승인하고 저장"은 포함한 건을 **한 트랜잭션으로** 저장하고 작업 기록을 남긴다(7.7). 저장 뒤에는 첫 건의 달로 옮겨 가고 "되돌리기"가 달린 알림을 띄운다.
  - 창 크기를 바꾸거나 다른 탭에 다녀와도 검토 중인 내용이 남는다. 닫으려 하면 버릴지 묻는다.
  - 거래가 아닌 것(안내문)과 읽지 못한 것은 아래에 접어 둔다. 읽지 못한 것은 "직접 입력"으로 넘길 수 있다.
- 화면: `ReviewPanel` — 6.2의 세 배치. 건마다 한 줄 요약(날짜 · 상대방 · 금액 · 분류), 펼치면 편집 칸.
- 데이터: 저장할 때 `transactions`와 `input_batches` · `input_batch_items`.
- 인터페이스: `reviewSessionProvider`(초안 목록, 포함 여부, 고친 값, `saveAll()`, `discard()`), `InputBatchRepository.saveBatch(drafts, source)`.
- 끝 기준: 묶음 저장이 원자적인 시험(중간에 실패하면 한 건도 남지 않는다), 이체로 바꿔 저장하는 시험, 경고를 둔 채 저장하면 `needs_review`인 시험, 세 배치에서 내용이 남는 시험.

### 7.7 작업 기록과 되돌리기 [예정]

- 규칙
  - 입력창 · 이미지 입력 · 가져오기로 저장한 묶음마다 언제 · 어떤 경로로 · 몇 건인지 남긴다. 원문은 남기지 않는다. 직접 입력한 거래는 묶음이 아니다.
  - 되돌리기: 묶음이 만든 거래 가운데 **그 뒤에 고치지 않은 것**(`client_updated_at`이 저장 때의 `stamp`와 같은 것)을 삭제 표시한다. 묶음이 취소 처리한 원 거래는 취소를 푼다. 고친 거래는 남기고 "3건을 되돌리고, 고친 1건은 남겼습니다"라고 알린다.
  - 되돌린 삭제는 평소의 동기화로 다른 기기에 전해진다. 작업 기록 자체는 기기마다 따로다(다른 기기에서는 보이지 않는다).
  - 되돌린 묶음은 `undone_at`을 적고 목록에 "되돌림"으로 남는다. 다시 되돌릴 수는 없다.
  - 기록은 90일 보관한다. 계정을 바꿔 "지우고 받기"를 하면 사라진다.
- 화면: `/history` — 묶음 목록(때, 경로, 건수, 상태). 누르면 그 묶음의 거래가 보이고 "이 묶음 되돌리기"가 있다. 저장 직후의 알림에도 "되돌리기"가 있다. 명령창과 Ctrl/⌘+Z로도 마지막 묶음을 되돌린다.
- 데이터: `input_batches`, `input_batch_items`.
- 인터페이스: `InputBatchRepository`(`saveBatch`, `watchBatches`, `undo(batchId)` → `UndoResult{undone, kept}`).
- 끝 기준: 되돌리기 시험(고치지 않은 것만 지운다, 취소를 푼다, 대기열에 올라간다), 두 번 되돌리지 못하는 시험, 화면 시험.

### 7.8 명령창과 단축키 [예정, PC 배치]

- 규칙
  - PC의 입력창이 명령창이다. 글을 적고 Enter면 거래로 해석한다. 적는 동안 맞는 명령을 아래에 보여 주고, 화살표로 골라 Enter면 그 명령을 실행한다. `>`로 시작하면 명령만 찾는다.
  - 명령: 화면 이동(홈 · 내역 · 통계 · 자산 · 분류 · 예산 · 반복 거래 · 작업 기록 · 설정), 새 지출 · 새 수입 · 새 이체, 붙여넣고 해석, 이전 달 · 다음 달 · 이번 달, 내역 검색, 마지막 입력 되돌리기, 테마 바꾸기(톤 넷), 지금 동기화, 단축키 도움말, 로그아웃.
  - 글자 한 개짜리 단축키는 글 칸 밖에서만 듣는다(한글 입력기가 켜져 있으면 브라우저가 키를 제대로 알려 주지 않는다). 브라우저가 쓰는 Ctrl+N/T/W/R/L/F/P/S는 쓰지 않는다. 브라우저가 Ctrl+K를 먼저 가져가면 `/`로 대신한다.

| 키 | 동작 |
| --- | --- |
| Ctrl/⌘+K | 명령창으로 |
| Ctrl/⌘+Enter | 모두 승인하고 저장(검토 중일 때) |
| ↑ / ↓ · Space · Enter · Delete | 검토 건 이동 · 포함/제외 · 고치기 · 제외 |
| `/` · `?` | 내역 검색 · 단축키 도움말 |
| `[` / `]` | 이전 달 / 다음 달 |
| Ctrl/⌘+Z | 마지막 묶음 되돌리기(글 칸 밖에서) |
| Esc | 닫기(검토 중이면 버릴지 묻는다) |

- 화면: 명령 목록은 입력창 아래에 붙는 칸. 단축키 도움말은 대화상자.
- 인터페이스: `AppCommand{id, title, keywords, shortcut, run}`, `commandsProvider`, `matchCommands(query)`, `CommandSuggestionList`, `AppShortcuts`(뼈대를 감싼다).
- 끝 기준: 명령 찾기 시험(한글 · 영문 낱말, `>`), 단축키가 글 칸 안에서는 듣지 않는 시험, 명령마다 실행 시험.

### 7.9 홈 [일부 구현, 예정]

- 규칙: 고른 달의 요약을 본다. 위에서부터 — 이번 달 지출(가장 크게)과 수입 · 수지, 예산 진행(정했을 때만), "확인 필요 N건"(있을 때만, 누르면 필터가 걸린 내역), 분류별 지출 상위 5, 최근 내역 5건, 첫 실행 안내(7.19).
- 화면: 휴대폰은 한 줄로 쌓고, PC는 두 칸. 빈 상태는 "아직 내역이 없습니다"와 입력창 안내.
- 인터페이스: `monthSummaryProvider`, `budgetProgressProvider`, `needsReviewCountProvider`.
- 끝 기준: 예산이 있을 때와 없을 때, 확인 필요가 있을 때의 화면 시험.

### 7.10 통계와 월별 요약 [일부 구현, 예정]

- 규칙
  - 통계: 지출 · 수입 전환. 분류 비중(막대, 분류 색), 날짜별 추이, 최근 6개월 추이, 상대방 상위 5, 큰 지출 5. 분류를 누르면 그 분류로 거른 내역으로 간다.
  - 월별 요약의 숫자: 수입 · 지출 · 수지, 지난달 대비, 분류별 금액과 비중, 예산 대비, 큰 지출 5, 상대방 5, **고정 지출**(출처가 `recurring`인 지출의 합), 하루 평균, 무지출 일수. 모두 SQL과 코드가 계산한다.
  - 총평: 모델이 있는 기기에서는 집계를 3–5문장으로 옮긴다. 집계에 없는 숫자가 나오면 버리고 다시 만들고, 두 번 실패하거나 모델이 없으면 **문장 틀**을 쓴다("이번 달은 지난달보다 12만 원 덜 썼습니다. 가장 많이 쓴 분류는 식비(32%)입니다. …").
  - 총평은 지난달까지만 만든다(이번 달은 숫자만). 통계 화면에서 그 달을 처음 열 때 만들어 `monthly_summaries`에 저장한다. `data_hash`는 집계 JSON의 SHA-256이고, 값이 달라지면 다시 만든다. 같은 달의 행이 겹치면 나중에 고친 것을 쓴다.
- 데이터: `monthly_summaries.stats`의 키 — `income`, `expense`, `net`, `previous_expense`, `by_category`[{`name`,`amount`,`ratio`}], `budget`{`amount`,`spent`}, `largest`[…], `counterparties`[…], `fixed_expense`, `daily_average`, `no_spend_days`.
- 인터페이스: `MonthSummary.toStatsJson()`, `monthNarrativeProvider(period)`, `NarrativeWriter`(모델) · `templateNarrative(stats)`(문장 틀).
- 끝 기준: 집계 시험(고정 지출, 예산 대비), 문장 틀 시험, 집계에 없는 숫자를 거르는 시험, 6개월 추이 화면 시험.

### 7.11 예산 [예정]

- 규칙
  - 달마다 전체 예산 하나와 분류별 예산을 정한다. 금액은 0 이상.
  - 남은 금액 = 예산 − 그 달의 지출(취소 · 이체 제외). 넘기면 경고색으로 "N원 넘음"을 보인다. 알림은 보내지 않는다.
  - 새 달에 예산이 없으면 "지난달 예산 가져오기"를 권한다. 저절로 복사하지 않는다.
  - 분류 예산의 합이 전체 예산을 넘으면 알려만 준다(막지 않는다).
  - 같은 달 · 같은 분류의 행이 둘 이상이면(두 기기가 따로 만든 경우) `client_updated_at`이 가장 늦은 것을 쓰고 나머지는 삭제 표시한다.
- 화면: `/budget` — 달 고르기, 전체 예산 진행 막대, 분류별 줄(예산 · 쓴 돈 · 남은 돈 · 막대). 줄을 누르면 금액을 고친다. 홈에는 전체 예산의 진행 막대 하나.
- 데이터: `budgets`.
- 인터페이스: `BudgetRepository`(`watchBudgets(ledgerId, month)`, `setBudget`, `deleteBudget`, `copyFromPreviousMonth`), `budgetProgressProvider`.
- 끝 기준: 겹친 행을 고르는 시험, 진행 계산 시험, 화면 시험.

### 7.12 카드 결제 처리 [예정]

- 규칙
  - 신용카드로 쓴 돈은 쓴 날의 지출이다. 카드대금이 계좌에서 빠져나가는 것은 **이체**(결제 계좌 → 카드 자산)로 적어 지출에 두 번 잡히지 않게 한다.
  - 결제 예정액 = 지난 결제일 다음 날부터 이번 결제일까지 그 카드로 쓴 지출의 합(취소 제외). 카드사마다 다른 실제 청구 기간과는 다를 수 있다고 화면에 적는다. 할부는 쓴 날에 전액을 잡는다.
  - 출금 문자의 상대방이 카드사 이름이고 그 카드 자산의 결제 계좌에서 나간 것이면 검토함이 이체로 제안한다.
  - 체크카드는 연결 계좌(`payment_account_id`)에서 바로 나간 것으로 보고, 카드 자산의 잔액은 따로 세지 않는다.
- 화면: `/accounts`의 카드 자산에 "다음 결제일 25일 · 예정 432,000원".
- 인터페이스: `cardDue(account, transactions, today)` → `CardDue{date, amount}`(도메인 함수).
- 끝 기준: 결제일이 월말을 넘는 달(31일 → 2월)의 시험, 취소 제외 시험, 검토함의 이체 제안 시험.

### 7.13 반복 거래와 할부 [예정]

- 규칙
  - 반복 규칙: 매주 · 매달 · 매년, 간격(1 이상), 다음 날짜, 끝나는 날(선택), 자동 등록 여부, 켜짐/꺼짐.
  - 만드는 때: 앱을 켤 때와 동기화가 끝난 뒤, `next_run_on`이 오늘 이전인 규칙마다 밀린 만큼 거래를 만들고 `next_run_on`을 다음으로 옮긴다. 한 번에 최대 24건(오래 쉰 경우).
  - 거래의 ID는 "규칙 ID + 날짜"에서 계산한 UUIDv5다. 두 기기가 같은 날짜를 만들어도 같은 행이 되어 한 건만 남는다.
  - 자동 등록이면 바로 `confirmed`로, 아니면 `needs_review`로 만든다(홈의 "확인 필요"에 뜬다). 출처는 `recurring`.
  - 매달 31일 같은 날짜는 그 달의 마지막 날로 당긴다.
  - 할부는 총액 한 건으로 적고 개월 수(`installment_months`)를 함께 적는다. 달마다 나누지 않는다.
- 화면: `/recurring` — 규칙 목록(이름, 금액, 주기, 다음 날짜), 추가 · 수정 · 끄기 · 삭제. 거래 편집에서 "반복으로 등록"을 누르면 그 거래를 틀로 규칙을 만든다.
- 데이터: `recurring_rules.template`의 키 — `type`, `amount`, `account_id`, `to_account_id`, `counterparty`, `category_id`, `memo`.
- 인터페이스: `RecurringRepository`(규칙의 추가 · 수정 · 삭제, `runDue(ledgerId, today)` → 만든 건수), `recurringRunnerProvider`(켤 때와 동기화 뒤에 돈다).
- 끝 기준: 밀린 날짜를 만드는 시험, 두 번 돌려도 늘지 않는 시험(같은 ID), 월말 시험, 화면 시험.

### 7.14 월 시작일 [구현됨]

- 급여일에 맞춰 1–28일 가운데 고른다. 15보다 크면 끝나는 달의 이름을 쓴다(25일 시작이면 10/25–11/24가 "11월"). 29–31일은 받지 않는다(달마다 길이가 달라서).

### 7.15 자연어 조회 [예정]

- 규칙
  - "지난달 식비 얼마야?" 같은 문장에서 **조건**을 읽는다: 기간, 분류, 상대방, 종류, 집계 방식(합계 · 건수 · 평균 · 목록).
  - 규칙이 먼저 읽는다(웹에서도 된다). 기간 낱말(오늘, 어제, 이번 주, 지난주, 이번 달, 지난달, 올해, 작년, N월, 최근 N일), 분류 이름, 집계 낱말(얼마, 몇 번, 평균, 보여 줘). 규칙이 못 읽고 모델이 있으면 모델이 조건 JSON을 만든다.
  - 기간은 기호로 받아 코드가 날짜 범위로 바꾼다(월 시작일 반영). 조건은 매개변수가 있는 SQL로만 실행한다. 모델이 SQL을 쓰지 않는다.
  - 결과에는 적용한 기간과 조건을 함께 보인다. 조건을 읽지 못했으면 그렇게 말하고 예시를 보여 준다.
  - 조회로 보는 문장: 금액이 없고, 물음 낱말(얼마, 몇, 언제, 뭐, 보여, 알려, 합계, 평균)이나 물음표가 있는 한 줄.
- 화면: `/query?q=…` — 문장, 읽은 조건(칩), 답(큰 숫자 또는 목록), "내역에서 보기".
- 인터페이스: `looksLikeQuery(text)`, `parseQuery(text, {today, categories, startDay})` → `LedgerQuery?`, `runQuery(repository, ledgerId, query)` → `QueryResult`.
- 조건 JSON(모델용): `{"period":"last_month","category":"식비","party":null,"type":"expense","agg":"sum"}`. `period`는 정해진 기호 가운데 하나, `category`는 분류 이름 가운데 하나.
- 끝 기준: 문장 30개의 조건 시험, 기간 계산 시험(월 시작일 25일), 조회로 보지 않아야 할 문장 시험("점심 9천원").

### 7.16 내보내기 · 가져오기 [예정]

- 규칙
  - 내보내기: 고른 기간의 거래를 CSV(UTF-8, BOM 포함 — Excel이 한글을 바로 연다) 또는 Excel(.xlsx)로. 열: 날짜, 시각, 종류, 금액, 자산, 받는 자산, 상대방, 분류, 메모, 할부, 취소 여부.
  - 가져오기: 이 앱이 내보낸 CSV는 그대로 읽는다. 다른 CSV는 첫 줄을 보여 주고 열을 맞춘다(날짜 · 금액 · 내용은 꼭 맞춰야 한다. 수입/지출 열이 따로면 둘 다 맞춘다). 인코딩은 UTF-8을 먼저 해 보고 안 되면 CP949로 읽는다.
  - 가져올 건은 검토함으로 보낸다(출처 `import`). 중복으로 보이는 건은 기본이 제외다. 한 번에 2,000건까지.
  - 없는 자산 · 분류 이름은 새로 만들지 묻는다.
- 화면: `/settings/data` — 내보내기(기간, 형식)와 가져오기(파일 고르기 → 열 맞추기 → 검토함).
- 인터페이스: `exportTransactions(rows, format)` → 바이트, `parseCsv(bytes)` → 표, `mapRows(table, mapping)` → 초안들. 파일 저장과 고르기는 `file_selector`(웹은 내려받기).
- 끝 기준: 내보낸 CSV를 다시 가져오면 같은 거래가 되는 시험, CP949 파일 시험, 열 맞추기 시험.

### 7.17 앱 잠금 [예정]

- 규칙
  - 숫자 4–6자리 잠금 번호. 모든 플랫폼. Android는 생체 인증을 함께 켤 수 있다.
  - 앱을 켤 때와, 뒤로 보냈다가 1분 넘어 돌아올 때 잠근다.
  - 번호는 솔트를 섞은 해시(PBKDF2-SHA256, 10만 번)로 기기 설정에 둔다. 서버로 가지 않는다.
  - 다섯 번 틀리면 30초 기다린다. 번호를 잊으면 "로그아웃하고 다시 로그인"으로 푼다(잠금이 꺼지고, 기기의 가계부는 그대로다).
  - 이 잠금은 화면을 가리는 것이다. 기기의 DB 파일을 암호화하지는 않는다(화면에 그렇게 적는다).
- 화면: `/settings/lock` — 켜기(번호 두 번 입력), 바꾸기, 끄기, 생체 인증. 잠금 화면은 번호판.
- 인터페이스: `AppLock`(`isEnabled`, `verify(pin)`, `setPin`, `clear`), `AppLockGate`(앱을 감싼다).
- 끝 기준: 해시 검증 시험, 다섯 번 틀린 뒤의 대기 시험, 1분 뒤 잠기는 시험.

### 7.18 공유 수신 [예정, Android]

- 규칙: 문자 앱 · 은행 앱의 "공유"에서 가계부를 고르면 글이 입력창에 채워진다. 바로 저장하지 않는다. 로그인 전이면 로그인한 뒤에 채운다. 앱이 꺼져 있었으면 켜진 뒤에 채운다.
- 데이터: 출처 `share`.
- 인터페이스: `ShareReceiver`(`Stream<String>`), 받은 글은 `incomingTextProvider`에 넣는다. 매니페스트에 `text/plain`의 SEND 인텐트 필터.
- 끝 기준: 받은 글이 입력창에 채워지는 시험. 실제 공유는 기기에서 확인한다.

### 7.19 첫 실행 안내 [예정]

- 규칙: 가입하고 처음 들어오면 홈 맨 위에 안내 카드를 보인다 — ① 자산 등록하기(카드와 계좌를 넣으면 문자를 알아서 잇는다) ② 결제 문자 붙여넣어 보기 ③ (앱) AI 모델 내려받기. 하나씩 끝내면 표시가 바뀌고, "닫기"를 누르거나 다 끝내면 다시 보이지 않는다(`onboarding.done`).
- 웹에서는 ③ 대신 "홈 화면에 추가"를 안내하고, 브라우저에 저장소 유지(`navigator.storage.persist`)를 청한다.
- 인터페이스: `OnboardingCard`.
- 끝 기준: 단계 표시와 닫기 시험.

### 7.20 설정 [일부 구현, 예정]

- 화면: 위에서부터 — 계정(이메일, 동기화 상태, 지금 동기화, 로그아웃) → 화면(테마) → 가계부(월 시작일) → 관리(자산, 분류, 예산, 반복 거래, 작업 기록) → 데이터(내보내기 · 가져오기, 동기화 충돌) → 보안(앱 잠금) → AI 모델(앱에서만) → 정보(버전, 업데이트 확인, 저장 위치, 오픈소스 라이선스, 개인정보 처리방침).
- 동기화 상태는 어느 화면에서나 알 수 있게 뼈대에도 작은 표시를 둔다(올릴 변경이 있거나 실패했을 때만).

### 7.21 업데이트 확인 [예정, Windows · Android]

- 규칙: 앱을 켤 때(하루 한 번) 저장소의 `catalog/version.json`(`{"latest":"1.2.0","min":"1.0.0","notes":"…","android":"<주소>","windows":"<주소>"}`)을 읽는다. 새 버전이 있으면 설정과 홈에 알린다. `min`보다 낮으면 꼭 올려야 한다고 알린다(막지는 않는다). 누르면 브라우저로 내려받기 주소를 연다. 웹은 새로 고치면 최신이다.
- 인터페이스: `UpdateChecker.check()` → `UpdateInfo?`, `UpdateBanner`.
- 끝 기준: 버전 비교 시험, 파일을 못 읽어도 조용히 넘어가는 시험.

### 7.22 배포 [일부 구현, 예정]

| 항목 | 내용 | 상태 |
| --- | --- | --- |
| 웹 | `main`에 올리면 GitHub Pages로 배포 | 구현됨 |
| Android APK | CI가 빌드한다. 저장소 비밀값(`ANDROID_KEYSTORE_BASE64` 등)이 있으면 그 키로, 없으면 디버그 키로 서명한다 | 예정 |
| Windows | Inno Setup 설치 파일(관리자 권한 없이 설치, URL 스킴 등록). VC++ 런타임은 함께 넣는다 | 예정 |
| 릴리스 | `v*` 태그를 올리면 APK와 설치 파일을 GitHub Releases에 올리고 `catalog/version.json`을 고친다 | 예정 |
| 서버 백업 | 매일 도는 작업이 DB를 덤프해 암호화하고 30일 보관한다. 비밀값(`SUPABASE_DB_URL`, `BACKUP_PASSPHRASE`)이 없으면 건너뛴다 | 예정 |
| 삭제 표시 정리 | 주마다 도는 작업이 `purge_tombstones()`를 부른다(같은 비밀값) | 예정 |
| 개인정보 처리방침 | `docs/PRIVACY.md` 초안. 무엇을 어디에 두는지, 지우는 방법 | 예정 |

---

## 8. 파일 구조

### 8.1 저장소

```
gagyebu/
├─ README.md               현황, 개발 방법
├─ docs/
│  ├─ SPEC.md              이 문서(설계의 원본)
│  ├─ PRIVACY.md           개인정보 처리방침 초안            [예정]
│  ├─ ui-palettes.json     팔레트 색 값
│  └─ screenshots/
├─ catalog/                앱이 읽는 공개 파일               [예정]
│  ├─ models.json          모델 카탈로그
│  └─ version.json         최신 버전
├─ installer/              Windows 설치 파일 스크립트        [예정]
├─ .github/workflows/      ci.yml(시험 · 빌드 · 웹 배포), release.yml · backup.yml [예정]
├─ app/                    Flutter 앱
├─ supabase/               서버: migrations/ · tests/ · README.md(규약, 연결 방법)
└─ eval/                   해석 평가: golden/ · tool/ · reports/ · README.md(실측 기록)
```

### 8.2 앱 (`app/lib`)

```
lib/
├─ main.dart
├─ app/                        앱 시작과 뼈대
│  ├─ bootstrap.dart           기기 설정 읽기, DB 열기, 서버 연결, 멈춘 탭 안내
│  ├─ app.dart                 MaterialApp, 테마 연결
│  ├─ router.dart              화면과 주소
│  ├─ providers.dart           상태 제공자
│  ├─ sync_controller.dart     로그인 상태를 따라 동기화 실행
│  ├─ background_jobs.dart     뒤에서 도는 일(반복 거래, 실시간 신호, 정리)을 켠다
│  ├─ engine_providers.dart    지금 쓸 LlmEngine · VisionEngine
│  └─ theme/                   palettes · tokens · app_theme · theme_setting
├─ core/                       날짜, 형식, 창 너비 등급, ID
├─ domain/                     열거형, 기본 분류, 월 기간, 월 집계, 카드 결제 예정
├─ ai/                         입력 해석(Flutter에 의존하지 않는다)
│  ├─ input_interpreter.dart   해석 순서
│  ├─ parsed_transaction.dart  거래 초안
│  ├─ text/                    규칙: 형식, 금액, 날짜, 방향, 이름 후보, 안내문, 한 줄 문장
│  ├─ llm/                     모델 요청, 출력 검증, 엔진, 모델 관리, 총평
│  ├─ query/                   자연어 조회: 조건 읽기와 실행
│  └─ vision/                  이미지 입력: 엔진 인터페이스, 추출, 검산
├─ platform/                   딥링크, 공유 수신, 업데이트 확인, 보안 저장소
├─ data/
│  ├─ db/                      표, DB, 변환기, 플랫폼별 연결(connection/)
│  ├─ prefs/                   기기 설정(shared_preferences)
│  ├─ repositories/            ledger · outbox_writer · account · category · budget · recurring · input_batch
│  ├─ sync/                    동기화 엔진, 규약의 형태, 가계부 옮기기
│  └─ server/                  서버 연결: 로그인, Supabase 구현, 설정
└─ features/                   화면
   ├─ shell/                   뼈대(탐색, 입력창과 검토함의 자리)
   ├─ common/                  함께 쓰는 위젯, 분류의 색과 아이콘
   ├─ auth/                    로그인 안내, 계정 만들기, 로그인, 비밀번호
   ├─ composer/                입력창
   ├─ review/                  검토함
   ├─ history/                 작업 기록과 되돌리기
   ├─ command/                 명령창과 단축키
   ├─ home/  stats/  transactions/
   ├─ accounts/  categories/  budget/  recurring/
   ├─ settings/                설정과 하위 화면(계정, 데이터, 충돌)
   ├─ lock/                    앱 잠금
   ├─ transfer/                내보내기 · 가져오기
   ├─ onboarding/              첫 실행 안내
   ├─ models/                  AI 모델 관리 화면
   ├─ query/                   조회 결과 화면
   └─ image_input/             이미지 입력 화면
```

`test/`는 `lib`과 같은 구조로 둔다. 파일 이름은 `<대상>_test.dart`.

### 8.3 기반이 깔아 두는 약속

여러 사람(에이전트)이 동시에 일할 수 있게, 모두가 건드리는 것은 기반 단계에서 한 번에 만들고 그 뒤에는 고치지 않는다. 기능은 아래 **자리**에 자기 구현을 채운다. 자리의 클래스 · 함수 · 제공자 **이름과 인자는 바꾸지 않는다**(바꿔야 하면 보고한다).

| 자리 | 파일 | 기반의 내용 | 채우는 곳 |
| --- | --- | --- | --- |
| 기기 설정 | `data/prefs/device_prefs.dart` | `DevicePrefs`(getString · setString · remove), `devicePrefsProvider` | 기반(완성) |
| 테마 | `app/theme/*` | 팔레트, `AppTokens`(`context.tokens`), `ThemeController` | 기반(완성) |
| 대기열 쓰기 | `data/repositories/outbox_writer.dart` | `OutboxWriter.enqueue` · `softDelete` | 기반(완성) |
| 분류의 색 · 아이콘 | `features/common/category_visual.dart` | `categoryColor(tokens, index)`, `categoryIcon(name, icon)` | 기반(완성) |
| 입력창 | `features/composer/composer_bar.dart` · `composer_state.dart` | `ComposerBar(placement)`: 글을 받아 옛 입력 화면으로 넘기는 간단한 구현. `incomingTextProvider` | A |
| 검토함 | `features/review/review_state.dart` · `review_panel.dart` | `reviewSessionProvider`(비어 있음), `reviewActiveProvider`, `ReviewPanel`, `ReviewScreen` | A |
| 작업 기록 | `features/history/history_screen.dart` | 빈 화면. `data/repositories/input_batch_repository.dart`는 A가 새로 만든다 | A |
| 명령 | `features/command/commands.dart` | `AppCommand`, `commandsProvider`(빈 목록), `CommandSuggestionList`(아무것도 그리지 않음), `AppShortcuts`(자식만 돌려줌) | B |
| 홈 · 통계 | `features/home/*`, `features/stats/*` | 지금 화면 | C |
| 내역 | `features/transactions/*` | 지금 화면 | D |
| 자산 · 분류 · 예산 · 반복 | `features/accounts` · `categories` · `budget` · `recurring`의 `*_screen.dart`, `data/repositories/budget_repository.dart` | 빈 화면. `BudgetRepository.watchBudgets` · `setBudget`만 있음. `account_` · `category_` · `recurring_repository.dart`와 `domain/card_due.dart`는 E가 새로 만든다 | E |
| 뒤에서 도는 일 | `features/recurring/recurring_runner.dart`(`recurringRunnerProvider`), `data/server/realtime.dart`(`realtimeSyncProvider`) | 아무 일도 하지 않는 제공자. `app/background_jobs.dart`가 켠다 | E, H |
| 설정 하위 화면 | `features/settings/account_screen.dart` · `conflicts_screen.dart`, `features/transfer/data_screen.dart`, `features/lock/lock_screen.dart`, 그리고 기반이 만든 `theme_card.dart` · `manage_links_card.dart` | 빈 화면 | F |
| 앱 잠금 | `features/lock/app_lock_gate.dart` | `AppLockGate(child)`: 자식만 돌려줌 | F |
| 첫 실행 안내 | `features/onboarding/onboarding_card.dart` | `OnboardingCard`: 아무것도 그리지 않음 | F |
| 엔진 | `app/engine_providers.dart` | `llmEngineProvider` · `visionEngineProvider`(둘 다 null). `app/providers.dart`가 다시 내보낸다 | G |
| 모델 화면 | `features/models/models_screen.dart` | 빈 화면 | G |
| 조회 | `ai/query/query_intent.dart`(`looksLikeQuery` → false), `features/query/query_screen.dart` | 빈 화면 | G |
| 총평 | `features/stats/narrative_provider.dart`(`monthNarrativeProvider` → null) | — | G |
| 이미지 입력 | `ai/vision/vision_engine.dart`(`VisionEngine`), `features/image_input/image_input_available.dart`(`imageInputAvailableProvider` → false), `features/image_input/image_input_screen.dart` | 빈 화면 | I |
| 업데이트 | `platform/update_checker.dart`(`UpdateBanner`: 아무것도 그리지 않음) | — | H |
| 공유 수신 · 딥링크 | `platform/share_receiver.dart` · `deep_links.dart` | 없음. H가 새로 만들고 `app/bootstrap.dart`에서 켠다 | H |

**주인이 정해진 공용 파일**

| 파일 | 주인 |
| --- | --- |
| `app/router.dart`, `app/app.dart`, `app/providers.dart`, `features/shell/*`, `data/db/*`, `data/repositories/ledger_repository.dart`, `core/*`, `pubspec.yaml`의 기존 줄 | 기반(합치는 사람). 기능 쪽은 고치지 않고, 필요하면 무엇이 왜 필요한지 보고한다 |
| `app/bootstrap.dart`, `app/sync_controller.dart`, `data/server/*`, `data/sync/*`, `android/`, `windows/` | H |
| `domain/month_summary.dart` | C |
| `features/settings/settings_screen.dart` | F |
| `ai/text/*`, `ai/input_interpreter.dart`, `ai/llm/*` | G(규칙을 고칠 일이 생기면) |
| `.github/`, `installer/`, `catalog/`, `docs/PRIVACY.md` | J |

새 의존성은 맡은 쪽이 `pubspec.yaml`의 `dependencies` 끝에 한 줄씩 더하고 `dart run tool/check_licenses.dart`가 통과하는지 확인한다.

### 8.4 일하는 규칙

- 시험을 함께 쓴다. `flutter analyze`와 `dart format`이 깨끗하고 자기 시험이 통과한 뒤에 커밋한다.
- 화면의 문장은 "…습니다" 체, 코드의 주석과 커밋 메시지는 한글 "…다" 체.
- 색 · 치수는 테마에서 읽는다. 위젯에는 시험이 찾을 수 있게 `ValueKey`를 단다.
- 쓰기는 저장소를 거치고 저장소는 `OutboxWriter`로 대기열에 올린다. 화면에서 DB를 직접 쓰지 않는다.
- 비밀값을 넣지 않는다. 사용자 계정이 필요한 것은 "넣는 자리"만 만들고 없을 때 조용히 건너뛰게 한다.
- 여기서 돌려 볼 수 없는 것(기기의 모델, 딥링크, 공유)은 인터페이스 뒤에 두고 가짜로 시험한다.

---

## 9. 빌드와 배포

푸시할 때마다 CI가 돈다(`.github/workflows/ci.yml`). Flutter 3.50.0.

| 작업 | 내용 |
| --- | --- |
| 분석 · 시험 · 라이선스 | 생성 코드가 최신인지, 형식, 분석, 시험, 의존성 라이선스 |
| 서버 SQL | PostgreSQL 16에서 마이그레이션과 시험 10묶음 |
| 웹 빌드 → 웹 배포 | `main`이면 GitHub Pages로 배포 |
| Android APK, Windows | 빌드해 Artifacts로 올린다 |

- 서버 주소와 publishable 키는 빌드할 때 넣는다(`--dart-define=SUPABASE_URL=…`, `SUPABASE_PUBLISHABLE_KEY=…`). CI는 저장소 변수가 없으면 지금 프로젝트의 값을 쓴다. 넣지 않고 빌드하면 로그인이 없는 개발용 앱이 된다.
- 웹: `dart run tool/prepare_web_assets.dart`가 `sqlite3.wasm`과 `drift_worker.js`를 준비한다. 글꼴(Pretendard)과 아이콘을 앱에 넣어 외부 글꼴 서버에 접속하지 않는다.
- 배포 주소는 `https://kimhershey.github.io/gagyebu/`를 쓴다. Google 로그인과 Supabase의 돌아올 주소가 여기에 맞춰져 있다.
- 릴리스 · 설치 파일 · 백업은 7.22.

---

## 10. 확인하지 못한 것과 사용자가 해야 하는 것

**기기에서 확인해야 하는 것**(이 저장소의 시험과 CI로는 알 수 없다)

- Android · Windows 앱의 실제 동작 전반(빌드만 확인한다)
- 기기 안의 모델: 내려받기, 추론 속도와 메모리, 정확도
- 이미지 입력의 정확도와 시간
- 앱에서의 Google 로그인 왕복, 공유 수신
- 실시간 신호로 두 기기가 5초 안에 맞춰지는지
- iPhone Safari에서 키보드가 올라올 때 입력창이 가려지는지, 한글 입력
- Google 로그인의 실제 왕복(웹), 비밀번호를 다시 정하는 메일

**사용자 계정에서 해야 하는 것**

| 무엇 | 어디서 |
| --- | --- |
| 앱 로그인의 돌아올 주소 추가(`io.github.kimhershey.gagyebu://login-callback`) | Supabase → Authentication → URL Configuration |
| 메일 서버(SMTP) 연결(여러 사람에게 메일을 보내려면) | Supabase → Authentication → Emails |
| APK 서명 키 | 저장소 Settings → Secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` |
| 백업 · 정리 작업 | 저장소 Secrets: `SUPABASE_DB_URL`, `BACKUP_PASSPHRASE` |
| 모델 파일의 주소와 해시 확인 | `catalog/models.json` |

**알려진 한계**

- 충돌은 행 단위로 판정한다(같은 거래의 다른 칸을 두 기기가 고치면 한쪽이 진다).
- 카드 결제 예정액은 단순한 규칙이라 실제 청구액과 다를 수 있다.
- 앱 잠금은 화면만 가린다. 기기의 DB 파일은 암호화하지 않는다.
- 웹에서는 브라우저가 저장소를 지울 수 있다(Safari는 7일 동안 열지 않은 사이트). 로그인해 있으면 다시 받는다.
- 작업 기록은 기기마다 따로다.

