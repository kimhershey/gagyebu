-- 0002_rls.sql
-- 행 수준 보안(RLS)과 테이블 권한.
--
-- 규칙
--  * 로그인한 사용자(authenticated)는 자기 가계부(ledgers.owner_id = auth.uid())의 행만 읽는다.
--  * 직접 쓰는 정책은 없다. 쓰기는 sync_push()(0003)만 한다. insert · update · delete 권한도 주지 않는다.
--  * sync_batches는 서버 전용이다. 정책도 권한도 없다.
--  * anon은 아무것도 못 한다.
--  * 정책에서는 auth.uid()를 (select auth.uid())로 감싼다. 행마다 다시 부르지 않고 한 번만 계산한다.
--
-- 테이블의 주인(postgres)은 RLS를 건너뛴다. SECURITY DEFINER 함수(0003, 0004)가 그 권한으로 쓴다.
-- 그래서 force row level security는 걸지 않는다.

-- ---------------------------------------------------------------------------
-- RLS 켜기
-- ---------------------------------------------------------------------------
alter table public.ledgers           enable row level security;
alter table public.profiles          enable row level security;
alter table public.accounts          enable row level security;
alter table public.categories        enable row level security;
alter table public.transactions      enable row level security;
alter table public.budgets           enable row level security;
alter table public.recurring_rules   enable row level security;
alter table public.category_rules    enable row level security;
alter table public.monthly_summaries enable row level security;
alter table public.sync_batches      enable row level security;

-- ---------------------------------------------------------------------------
-- 권한
-- Supabase는 public 스키마에 만든 테이블 · 시퀀스의 모든 권한을 anon · authenticated에게 기본으로 준다.
-- 전부 걷어 내고 authenticated에게 조회만 돌려준다.
-- ---------------------------------------------------------------------------
revoke all on table
  public.ledgers, public.profiles, public.accounts, public.categories, public.transactions,
  public.budgets, public.recurring_rules, public.category_rules, public.monthly_summaries,
  public.sync_batches
from public, anon, authenticated;

revoke all on sequence public.server_seq from public, anon, authenticated;

grant select on table
  public.ledgers, public.profiles, public.accounts, public.categories, public.transactions,
  public.budgets, public.recurring_rules, public.category_rules, public.monthly_summaries
to authenticated;

-- ---------------------------------------------------------------------------
-- 조회 정책: 자기 가계부의 행만
-- ---------------------------------------------------------------------------
create policy ledgers_select_own on public.ledgers
  for select to authenticated
  using (owner_id = (select auth.uid()));

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (ledger_id in (select l.id from public.ledgers l where l.owner_id = (select auth.uid())));

create policy accounts_select_own on public.accounts
  for select to authenticated
  using (ledger_id in (select l.id from public.ledgers l where l.owner_id = (select auth.uid())));

create policy categories_select_own on public.categories
  for select to authenticated
  using (ledger_id in (select l.id from public.ledgers l where l.owner_id = (select auth.uid())));

create policy transactions_select_own on public.transactions
  for select to authenticated
  using (ledger_id in (select l.id from public.ledgers l where l.owner_id = (select auth.uid())));

create policy budgets_select_own on public.budgets
  for select to authenticated
  using (ledger_id in (select l.id from public.ledgers l where l.owner_id = (select auth.uid())));

create policy recurring_rules_select_own on public.recurring_rules
  for select to authenticated
  using (ledger_id in (select l.id from public.ledgers l where l.owner_id = (select auth.uid())));

create policy category_rules_select_own on public.category_rules
  for select to authenticated
  using (ledger_id in (select l.id from public.ledgers l where l.owner_id = (select auth.uid())));

create policy monthly_summaries_select_own on public.monthly_summaries
  for select to authenticated
  using (ledger_id in (select l.id from public.ledgers l where l.owner_id = (select auth.uid())));

-- sync_batches에는 정책을 만들지 않는다. RLS가 켜져 있으므로 아무 행도 보이지 않는다.

-- ---------------------------------------------------------------------------
-- 실시간 신호 채널(Supabase 전용)
-- sync_push()는 비공개 채널 'ledger:<ledger_id>'로 변경 신호를 보낸다(0003).
-- 비공개 채널에는 realtime.messages의 조회 정책을 통과한 사용자만 들어올 수 있다. Realtime 서버는
-- 채널에 들어오려는 사용자의 토큰과 주제(realtime.topic())를 걸고, 그 주제의 행이 보이는지로 판정한다.
-- 가계부의 주인만 자기 채널을 듣게 한다. 보내기(insert) 정책은 두지 않는다. 기기는 신호를 보낼 수 없다.
-- realtime 스키마가 없는 곳(로컬 PostgreSQL)에서는 건너뛴다.
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('realtime.messages') is null or to_regprocedure('realtime.topic()') is null then
    raise notice 'realtime 스키마가 없다. 실시간 채널 정책은 만들지 않는다.';
    return;
  end if;

  execute 'drop policy if exists ledger_signal_select_own on realtime.messages';
  execute $policy$
    create policy ledger_signal_select_own on realtime.messages
      for select to authenticated
      using (
        realtime.messages.extension = 'broadcast'
        and realtime.messages.topic = (select realtime.topic())
        and exists (
          select 1
          from public.ledgers l
          where l.owner_id = (select auth.uid())
            and 'ledger:' || l.id::text = realtime.messages.topic
        )
      )
  $policy$;
exception when insufficient_privilege then
  -- 신호가 없어도 동기화는 된다(기기가 주기적으로 pull한다). 배포를 막지 않고 경고만 남긴다.
  raise warning 'realtime.messages에 정책을 만들 권한이 없다(%). 대시보드에서 ledger_signal_select_own 정책을 직접 만들어야 실시간 신호가 전달된다.', sqlerrm;
end $$;
