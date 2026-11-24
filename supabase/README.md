# supabase/

서버 쪽 SQL이다. Supabase 프로젝트(서울 리전, PostgreSQL)에 그대로 적용한다.
서버는 인증 · 저장 · 동기화만 맡고, 추론은 하지 않는다.

```
migrations/
  0001_schema.sql        테이블 9개 + sync_batches
  0002_rls.sql           행 수준 보안. 자기 가계부만 읽고, 직접 쓰기는 막는다
  0003_sync.sql          sync_push(), sync_pull()
  0004_lifecycle.sql     가입 시 시드, 계정 삭제, 삭제 표시 정리
tests/
  run_local.sh           임시 PostgreSQL을 띄워 마이그레이션과 시험을 돌린다
  00_supabase_stub.sql   로컬 시험용으로 auth · realtime 스키마와 역할을 흉내 낸다(운영에는 적용하지 않는다)
  _helpers.sql           시험이 함께 쓰는 도우미
  10–90_*.sql            시험: 가입 시드, RLS, push · pull, 멱등, 충돌, 적대적 입력, 수명 주기, 동시성, 변경 신호
```

## 원칙

- 클라이언트는 테이블을 **읽기만** 한다. 쓰기는 전부 `sync_push()`를 거친다.
  이렇게 해야 `server_seq` 순서와 커밋 순서가 가계부 안에서 일치한다.
- 모든 행은 가계부(`ledger_id`) 단위로 격리한다. `ledgers.owner_id = auth.uid()`인 가계부만 보인다.
- `server_seq`는 전역 시퀀스 하나에서 받는다. 기기는 가계부별 커서(마지막으로 받은 `server_seq`) 하나만 기억한다.
- 삭제는 `deleted_at` 표시로 전파하고, 90일이 지나면 실제로 지운다.

## 행의 JSON 표현

컬럼 이름을 그대로 키로 쓴다(snake_case).

| SQL 타입 | JSON |
| --- | --- |
| uuid, text | 문자열 |
| bigint, integer, smallint | 숫자 |
| numeric | 숫자 |
| date | `"YYYY-MM-DD"` |
| time | `"HH:MM:SS"` |
| timestamptz | ISO 8601 문자열(UTC) |
| text[] | 문자열 배열 |
| jsonb | 객체 |
| boolean | true · false |

## sync_push

```
sync_push(p_ledger_id uuid, p_device_id uuid, p_batch_id uuid, p_changes jsonb) returns jsonb
```

`p_changes`는 변경 배열이다.

```json
[
  {
    "table": "transactions",
    "op": "upsert",
    "id": "018f…",
    "base_version": 0,
    "client_updated_at": "2026-11-17T05:00:00Z",
    "data": { "type": "expense", "occurred_on": "2026-11-16", "amount": 12500, "account_id": "…" }
  },
  { "table": "transactions", "op": "delete", "id": "018f…", "base_version": 3,
    "client_updated_at": "2026-11-17T05:01:00Z" }
]
```

- `table`: `ledgers`, `profiles`, `accounts`, `categories`, `transactions`, `budgets`,
  `recurring_rules`, `category_rules`, `monthly_summaries` 중 하나.
- `op`: `upsert` 또는 `delete`.
- `base_version`: 기기가 이 변경을 만들 때 알고 있던 서버 버전. 기기가 새로 만든 행은 0.
- `data`: `upsert`일 때 행 전체. 서버가 관리하는 컬럼(`id`, `ledger_id`, `version`, `server_seq`,
  `created_at`, `updated_at`, `deleted_at`, `client_updated_at`, 생성 컬럼 `counterparty`)은 넣어도 무시한다.

처리 순서와 규칙:

1. `auth.uid()`가 `p_ledger_id`의 소유자인지 확인한다. 아니면 예외(`42501`).
2. 가계부 단위 트랜잭션 잠금을 잡는다(`pg_advisory_xact_lock`). 같은 가계부의 push는 차례로 처리된다.
3. `(p_ledger_id, p_batch_id)`가 `sync_batches`에 있으면 저장된 결과를 그대로 돌려준다(멱등).
4. 변경을 테이블 의존 순서로 정렬해 적용한다:
   `ledgers`, `profiles`, `accounts`, `categories`, `transactions`, `budgets`, `recurring_rules`,
   `category_rules`, `monthly_summaries`. 같은 테이블 안에서는 보낸 순서를 지킨다.
5. `client_updated_at`이 서버 시각보다 앞서 있으면 서버 시각으로 자른다.
6. 변경 하나의 판정:

   | 서버의 행 | 조건 | 결과 |
   | --- | --- | --- |
   | 없음 | `upsert` | 새로 넣는다. `version = 1`. 상태 `applied` |
   | 없음 | `delete` | 할 일이 없다. 상태 `applied`, `version = 0` |
   | 있음 | `base_version = version` | 적용한다. `version + 1`. 상태 `applied` |
   | 있음 | `base_version <> version`, 들어온 `client_updated_at`이 서버 행보다 늦다 | 적용한다. 상태 `conflict_won`, `server_row`에 덮어쓰기 전 행 |
   | 있음 | `base_version <> version`, 그 밖 | 적용하지 않는다. 상태 `conflict_lost`, `server_row`에 현재 행 |

   - 다른 가계부의 행 ID를 건드리면 그 변경은 `error`다.
   - `ledgers`는 `upsert`로 `name`, `currency`만 고칠 수 있다. 만들거나 지울 수 없다.
   - `profiles`는 `id = auth.uid()`인 행만 고칠 수 있다. 지울 수 없다.
   - 제약 위반 등으로 한 건이 실패하면 그 건만 `error`로 돌려주고 나머지는 계속 처리한다.
7. 적용한 행마다 `server_seq = nextval('server_seq')`, `updated_at = now()`를 쓴다.
   `delete`는 `deleted_at = now()`를 쓴다. 이미 삭제 표시가 있던 행을 `upsert`하면 삭제 표시를 지운다.
8. 결과를 `sync_batches`에 넣고 돌려준다. Supabase에서는 실시간 채널 `ledger:<ledger_id>`로
   변경 신호(`event = 'changed'`, 내용은 마지막 `server_seq`뿐)를 보낸다.

반환:

```json
{
  "batch_id": "…",
  "server_time": "2026-11-17T05:00:01.123Z",
  "max_server_seq": 1042,
  "results": [
    { "table": "transactions", "id": "018f…", "status": "applied",
      "version": 1, "server_seq": 1041, "server_row": null, "error": null }
  ]
}
```

`results`는 `p_changes`와 같은 순서다. `max_server_seq`는 이 묶음이 쓴 가장 큰 `server_seq`이고,
아무것도 쓰지 않았으면 null이다.

## sync_pull

```
sync_pull(p_ledger_id uuid, p_since bigint, p_limit integer default 500) returns jsonb
```

`server_seq > p_since`인 행을 모든 동기화 테이블에서 모아 `server_seq` 오름차순으로 최대 `p_limit`건 돌려준다.
삭제 표시가 있는 행도 포함한다. `p_limit`은 1–2000으로 자른다.

```json
{
  "changes": [ { "table": "accounts", "row": { "id": "…", "ledger_id": "…", "version": 2, "server_seq": 1040, "deleted_at": null } } ],
  "next_seq": 1041,
  "has_more": false,
  "server_time": "2026-11-17T05:00:02.000Z"
}
```

- `ledgers` 행은 `id = p_ledger_id`인 것을 준다. `row`에 `ledger_id` 키는 없다.
- `next_seq`는 돌려준 마지막 행의 `server_seq`이고, 돌려준 행이 없으면 `p_since`다.
- 소유자가 아니면 예외(`42501`).

## 그 밖의 함수

- `handle_new_user()` — `auth.users`에 행이 생기면 가계부 1개, 프로필, 기본 분류, 현금 자산을 만든다.
  기본 분류 이름은 앱의 `lib/domain/default_seed.dart`와 같아야 한다.
- `delete_my_account()` — 호출한 사용자의 가계부와 모든 행, 인증 계정을 지운다.
- `purge_tombstones(p_older_than interval default '90 days')` — 오래된 삭제 표시 행을 실제로 지운다.
  서비스 역할만 실행한다.

## 구현하면서 정한 것

규약이 정하지 않은 부분을 `0003_sync.sql`에서 다음과 같이 정했다. 시험이 모두 덮는다.

- `data`에 없는 컬럼은 새 행이면 기본값, 있던 행이면 지금 값을 그대로 둔다. 값을 비우려면 `null`을 보낸다.
- 같은 묶음에서 같은 행을 다시 고치면 보낸 순서대로 이어서 적용한다(행 하나에 100번까지).
- 다른 행을 가리키는 값(`account_id`, `to_account_id`, `category_id`)은 같은 가계부의 행이어야 한다. 없는 행과 남의 가계부 행은 같은 오류로 답한다.
- JSON으로 적을 수 없는 값(infinity, 기원전 날짜, 다섯 자리 연도, NaN)은 그 변경만 `error`다.
- 변경의 잘못이 아닌 실패(교착, 잠금 시간 초과, 자원 부족)는 `error`로 기록하지 않고 호출 전체를 실패시킨다. 기기는 같은 묶음을 다시 보낸다.
- 결과의 `version` · `server_seq`는 처리한 뒤 서버 행의 값이다. `conflict_lost`면 지금 서버 행의 값, 없는 행의 `delete`면 `0`과 `null`이다.
- 시각은 `"2026-11-17T05:00:01.123456+00:00"`처럼 마이크로초와 `+00:00`으로 내려간다.
- 변경 신호는 비공개 채널 `ledger:<ledger_id>`로 보낸다. 기기는 `private: true`로 구독해야 한다.
- 함수의 `search_path`는 `pg_catalog, pg_temp`로 고정했다. `''`로 두면 세션의 임시 타입이 `jsonb` 같은 이름을 가릴 수 있다.

## 기기가 지켜야 하는 것

- 내려받은 행을 적용할 때 외래 키를 강제하지 않는다. 내려오는 순서는 `server_seq` 순서라서 거래가 그 자산보다 먼저 올 수 있다.
- push 결과의 `server_seq`와 `max_server_seq`로 pull 커서를 옮기지 않는다. 다른 기기가 쓴 더 작은 번호의 행을 아직 받지 않았을 수 있다.
- 한 묶음은 500건 안쪽으로 보내고, 대기열에 쌓인 순서(부모 행이 먼저)를 지킨다.
- 문자열의 NUL 문자(U+0000)는 빼고 보낸다. jsonb가 받지 않아 호출 전체가 실패한다.
- 90일 넘게 받지 않은 기기는 커서를 0으로 되돌려 전체를 다시 받는다. 그 사이 정리된 삭제 표시를 놓쳤을 수 있다.

## 알려진 한계

- 충돌은 행 단위로 나중에 고친 쪽이 이긴다. 같은 행의 다른 필드를 두 기기가 따로 고쳐도 한쪽 내용이 진다. 시계가 느린 기기는 이겨야 할 충돌에서 질 수 있다(빠른 시계만 서버 시각으로 자른다).
- 자연 키의 유일성을 서버가 지키지 않는다. 두 기기가 오프라인에서 같은 달 · 같은 분류의 예산을 따로 만들면 둘 다 남는다. 기기가 합쳐야 한다.
- 대시보드나 서비스 키로 테이블을 직접 고치면 `server_seq`가 오르지 않아 기기로 전파되지 않는다. 쓰기는 `sync_push()`로만 한다.
- 백업에서 복원하면 `server_seq`가 기기의 커서보다 작아질 수 있다. 복원한 뒤에는 기기에서 전체를 다시 받아야 한다.
- 트리거를 설치하기 전에 가입한 사용자에게는 가계부가 만들어지지 않는다.
- `purge_tombstones()`를 주기적으로 부르는 예약은 아직 없다.

## 프로젝트를 만들어 앱에 연결하기

1. Supabase에서 프로젝트를 만든다. 리전은 서울(ap-northeast-2).
2. `migrations/`의 파일 네 개를 번호 순서대로 적용한다. 대시보드의 SQL Editor에 붙여 넣어 실행하거나 Supabase CLI의 `supabase db push`를 쓴다.
3. Google 로그인을 켠다.
   - Google Cloud Console에서 OAuth 클라이언트(웹 애플리케이션)를 만든다. 승인된 리디렉션 URI에 `https://<프로젝트>.supabase.co/auth/v1/callback`을 넣는다.
   - Supabase 대시보드의 Authentication → Providers → Google에 클라이언트 ID와 비밀값을 넣는다.
   - Authentication → URL Configuration의 Redirect URLs에 웹 앱 주소(예: `https://kimhershey.github.io/gagyebu/`)를 넣는다. 로컬에서 시험하려면 `http://localhost:*`도 넣는다.
4. 이메일 로그인은 처음부터 켜져 있다(Authentication → Providers → Email). 가입하면 확인 메일의 링크를 눌러야 로그인된다(Confirm email). Supabase가 기본으로 주는 메일 발송은 시험용이라 보낼 수 있는 주소와 횟수에 제한이 있다. 여러 사람이 가입하게 하려면 메일 서버(SMTP)를 연결하거나 Confirm email을 끈다.
5. Project URL과 publishable 키를 앱 빌드에 넣는다(저장소 `README.md`의 "개발"). 이 두 값은 공개해도 된다. service_role 키와 DB 비밀번호는 어디에도 넣지 않는다.

앱은 로그인하면 `profiles`에서 제 가계부를 찾고(`id = auth.uid()`), `sync_push` · `sync_pull`만 부른다. 처음 로그인한 기기는 그동안 기기에 적어 둔 거래 · 자산 · 분류를 계정의 가계부로 옮긴다. 이름과 종류가 같은 기본 분류 · 자산은 서버 것을 쓰고, 나머지는 새 행으로 올린다(`app/lib/data/sync/ledger_adoption.dart`).

## 실제 Supabase에서 확인할 것

로컬 시험은 Supabase가 제공하는 것을 스텁(`tests/00_supabase_stub.sql`)으로 흉내 냈다. 프로젝트에 적용한 뒤 아래를 확인한다.

- `realtime.send()`의 실제 동작과, `postgres` 역할이 `realtime.messages`에 정책을 만들 수 있는지. 적용 뒤 `ledger_signal_select_own` 정책이 있는지 본다.
- `private: true`로 구독한 기기에 변경 신호가 오는지.
- 가입할 때 `auth.users`의 트리거가 실제로 도는지, `delete_my_account()`가 인증 계정까지 지우는지.
- PostgREST를 거친 호출에서 매개변수 이름이 맞는지와 문장 제한 시간.

## 로컬에서 시험하기

```bash
supabase/tests/run_local.sh
```

PostgreSQL 16이 설치돼 있어야 한다. 임시 클러스터를 만들어 스텁 → 마이그레이션 → 시험 순으로 실행하고 지운다.
`-v`는 psql 출력을 모두 보여 주고, `--keep`은 끝나도 클러스터를 지우지 않는다.
