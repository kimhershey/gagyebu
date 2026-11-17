-- 0001_schema.sql
-- 가계부 서버 스키마. 기기의 SQLite(Drift) 테이블이 같은 컬럼을 갖는다.
-- 기준 문서: 설계안 "데이터 모델", "동기화 · 인증 · 보안".
--
-- 규칙
--  * 금액은 원 단위 정수(bigint), 날짜는 사용자 현지 날짜(date)다.
--  * 동기화하는 모든 테이블은 공통 컬럼
--      id, ledger_id, version, server_seq, client_updated_at,
--      created_at, updated_at, deleted_at
--    을 갖는다. ledgers는 id가 곧 가계부 ID라서 ledger_id가 없다.
--  * 쓰기는 sync_push() RPC로만 한다(0003). 테이블에 직접 쓰는 정책은 두지 않는다(0002).
--  * 열거형은 text + check 제약으로 둔다. JSON으로 주고받기 쉽고 값 추가가 간단하다.

create sequence if not exists public.server_seq as bigint;

-- ---------------------------------------------------------------------------
-- ledgers: 가계부 단위. 가입할 때 서버가 사용자당 1개를 만든다(0004).
-- ---------------------------------------------------------------------------
create table public.ledgers (
  id                uuid primary key,
  owner_id          uuid not null references auth.users (id) on delete cascade,
  name              text not null,
  currency          text not null default 'KRW',
  version           integer not null default 1,
  server_seq        bigint not null default nextval('public.server_seq'),
  client_updated_at timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);
create index ledgers_owner_idx on public.ledgers (owner_id);

-- ---------------------------------------------------------------------------
-- profiles: 사용자 설정. id는 인증 사용자 ID를 그대로 쓴다.
-- ---------------------------------------------------------------------------
create table public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  ledger_id          uuid not null references public.ledgers (id) on delete cascade,
  display_name       text,
  month_start_day    smallint not null default 1 check (month_start_day between 1 and 28),
  default_account_id uuid,
  version            integer not null default 1,
  server_seq         bigint not null default nextval('public.server_seq'),
  client_updated_at  timestamptz not null default now(),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz
);
create index profiles_ledger_seq_idx on public.profiles (ledger_id, server_seq);

-- ---------------------------------------------------------------------------
-- accounts: 자산(현금 · 계좌 · 카드 · 간편결제)
-- ---------------------------------------------------------------------------
create table public.accounts (
  id                 uuid primary key,
  ledger_id          uuid not null references public.ledgers (id) on delete cascade,
  name               text not null,
  kind               text not null check (kind in ('cash', 'bank', 'credit_card', 'check_card', 'pay', 'other')),
  institution        text,
  -- 원문의 카드 · 계좌 표기와 맞춰 보는 식별 문구. 예: {'신한카드', '1234'}
  match_hints        text[] not null default '{}',
  opening_balance    bigint not null default 0,
  -- 신용카드 결제일(1–31)
  billing_day        smallint check (billing_day between 1 and 31),
  -- 신용카드 대금이 빠지는 계좌, 체크카드가 연결된 계좌. 자기 참조라 FK는 두지 않는다.
  payment_account_id uuid,
  sort_order         integer not null default 0,
  version            integer not null default 1,
  server_seq         bigint not null default nextval('public.server_seq'),
  client_updated_at  timestamptz not null default now(),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz
);
create index accounts_ledger_seq_idx on public.accounts (ledger_id, server_seq);

-- ---------------------------------------------------------------------------
-- categories: 분류(대분류 · 소분류)
-- ---------------------------------------------------------------------------
create table public.categories (
  id                uuid primary key,
  ledger_id         uuid not null references public.ledgers (id) on delete cascade,
  kind              text not null check (kind in ('expense', 'income')),
  name              text not null,
  -- 소분류면 대분류 ID. 자기 참조라 FK는 두지 않는다.
  parent_id         uuid,
  icon              text,
  sort_order        integer not null default 0,
  version           integer not null default 1,
  server_seq        bigint not null default nextval('public.server_seq'),
  client_updated_at timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);
create index categories_ledger_seq_idx on public.categories (ledger_id, server_seq);

-- ---------------------------------------------------------------------------
-- transactions: 거래 내역
-- ---------------------------------------------------------------------------
create table public.transactions (
  id                 uuid primary key,
  ledger_id          uuid not null references public.ledgers (id) on delete cascade,
  type               text not null check (type in ('expense', 'income', 'transfer')),
  occurred_on        date not null,
  occurred_time      time,
  -- 원 단위 정수. 방향은 type이 정하고 값은 양수다. 부분 취소와 환불만 음수로 적는다.
  amount             bigint not null,
  -- 해외 결제의 원래 통화와 금액. amount에는 원화 환산액을 적는다.
  currency           text,
  original_amount    numeric,
  account_id         uuid not null references public.accounts (id),
  to_account_id      uuid references public.accounts (id),
  sender             text,
  receiver           text,
  -- 상대방. 입금이면 sender, 출금이면 receiver, 이체는 비운다.
  counterparty       text generated always as (
                       case type when 'income' then sender when 'expense' then receiver else null end
                     ) stored,
  category_id        uuid references public.categories (id),
  memo               text,
  tags               text[] not null default '{}',
  installment_months integer check (installment_months is null or installment_months >= 2),
  balance_after      bigint,
  canceled_at        timestamptz,
  source             text not null default 'manual'
                       check (source in ('manual', 'nl', 'paste', 'image', 'share', 'import', 'recurring')),
  ai_model           text,
  status             text not null default 'confirmed' check (status in ('confirmed', 'needs_review')),
  dedup_key          text,
  version            integer not null default 1,
  server_seq         bigint not null default nextval('public.server_seq'),
  client_updated_at  timestamptz not null default now(),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz,
  check (type <> 'transfer' or to_account_id is not null),
  check (type = 'transfer' or to_account_id is null)
);
create index transactions_ledger_seq_idx on public.transactions (ledger_id, server_seq);
create index transactions_ledger_date_idx on public.transactions (ledger_id, occurred_on);
create index transactions_ledger_dedup_idx on public.transactions (ledger_id, dedup_key);

-- ---------------------------------------------------------------------------
-- budgets: 월 예산. category_id가 비면 전체 예산이다.
-- ---------------------------------------------------------------------------
create table public.budgets (
  id                uuid primary key,
  ledger_id         uuid not null references public.ledgers (id) on delete cascade,
  -- 'YYYY-MM'
  month             text not null check (month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  category_id       uuid references public.categories (id),
  amount            bigint not null check (amount >= 0),
  version           integer not null default 1,
  server_seq        bigint not null default nextval('public.server_seq'),
  client_updated_at timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);
create index budgets_ledger_seq_idx on public.budgets (ledger_id, server_seq);

-- ---------------------------------------------------------------------------
-- recurring_rules: 반복 거래(월세 · 구독 · 급여)
-- ---------------------------------------------------------------------------
create table public.recurring_rules (
  id                uuid primary key,
  ledger_id         uuid not null references public.ledgers (id) on delete cascade,
  -- 만들 거래의 틀. transactions 컬럼 이름을 키로 쓴다.
  template          jsonb not null,
  frequency         text not null check (frequency in ('weekly', 'monthly', 'yearly')),
  interval_count    integer not null default 1 check (interval_count >= 1),
  next_run_on       date not null,
  end_on            date,
  -- true면 날짜가 되면 바로 거래로 만들고, false면 확인을 받는다.
  auto_post         boolean not null default false,
  is_active         boolean not null default true,
  version           integer not null default 1,
  server_seq        bigint not null default nextval('public.server_seq'),
  client_updated_at timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);
create index recurring_rules_ledger_seq_idx on public.recurring_rules (ledger_id, server_seq);

-- ---------------------------------------------------------------------------
-- category_rules: 사용자가 고친 분류를 기억하는 규칙
-- ---------------------------------------------------------------------------
create table public.category_rules (
  id                uuid primary key,
  ledger_id         uuid not null references public.ledgers (id) on delete cascade,
  -- 상대방 문자열(정규화한 값)
  pattern           text not null,
  category_id       uuid not null references public.categories (id),
  hit_count         integer not null default 0,
  version           integer not null default 1,
  server_seq        bigint not null default nextval('public.server_seq'),
  client_updated_at timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);
create index category_rules_ledger_seq_idx on public.category_rules (ledger_id, server_seq);

-- ---------------------------------------------------------------------------
-- monthly_summaries: 월별 요약 보관. 한 기기에서 만든 요약을 다른 기기에서 그대로 본다.
-- ---------------------------------------------------------------------------
create table public.monthly_summaries (
  id                uuid primary key,
  ledger_id         uuid not null references public.ledgers (id) on delete cascade,
  month             text not null check (month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  -- SQL 집계 결과
  stats             jsonb not null,
  -- LLM 총평. 모델이 없는 기기에서 만든 요약은 비어 있다.
  narrative         text,
  -- 집계에 쓴 거래의 해시. 거래가 바뀌면 다시 만든다.
  data_hash         text,
  ai_model          text,
  version           integer not null default 1,
  server_seq        bigint not null default nextval('public.server_seq'),
  client_updated_at timestamptz not null default now(),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz
);
create index monthly_summaries_ledger_seq_idx on public.monthly_summaries (ledger_id, server_seq);

-- ---------------------------------------------------------------------------
-- sync_batches: push 묶음의 처리 결과. 같은 묶음을 다시 보내면 저장된 결과를 돌려준다.
-- 서버 전용이며 기기로 내려가지 않는다.
-- ---------------------------------------------------------------------------
create table public.sync_batches (
  ledger_id  uuid not null references public.ledgers (id) on delete cascade,
  batch_id   uuid not null,
  device_id  uuid not null,
  result     jsonb not null,
  created_at timestamptz not null default now(),
  primary key (ledger_id, batch_id)
);
