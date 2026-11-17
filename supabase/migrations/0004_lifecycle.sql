-- 0004_lifecycle.sql
-- 계정의 처음과 끝: 가입할 때의 시드, 계정 삭제, 오래된 삭제 표시 정리.
--
--   handle_new_user()    auth.users에 행이 생기면 가계부 · 프로필 · 기본 분류 · 현금 자산을 만든다(트리거).
--   delete_my_account()  호출한 사용자의 가계부와 모든 행, 인증 계정을 지운다.
--   purge_tombstones()   오래된 삭제 표시 행을 실제로 지운다. 서비스 역할만 실행한다.
--
-- 세 함수 모두 SECURITY DEFINER다. search_path를 고정하는 까닭은 0003의 머리말에 적었다.

-- ---------------------------------------------------------------------------
-- FK 확인용 인덱스
-- 자산 · 분류 행을 실제로 지울 때(계정 삭제, 삭제 표시 정리) PostgreSQL은 그 행을 가리키는 행이
-- 남아 있는지 FK마다 찾아본다. 인덱스가 없으면 지우는 행마다 테이블 전체를 훑는다.
-- ---------------------------------------------------------------------------
create index if not exists transactions_account_idx
  on public.transactions (account_id);
create index if not exists transactions_to_account_idx
  on public.transactions (to_account_id) where to_account_id is not null;
create index if not exists transactions_category_idx
  on public.transactions (category_id) where category_id is not null;
create index if not exists budgets_category_idx
  on public.budgets (category_id) where category_id is not null;
create index if not exists category_rules_category_idx
  on public.category_rules (category_id);

-- ---------------------------------------------------------------------------
-- handle_new_user: 가입 시 시드
-- 기본 분류 이름은 앱의 lib/domain/default_seed.dart와 같아야 한다(가운뎃점은 U+00B7).
-- 여기서 받는 server_seq는 새 가계부의 것이라 아직 아무 기기도 읽지 않는다. 잠금이 필요 없다.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_ledger_id  uuid := gen_random_uuid();
  v_account_id uuid := gen_random_uuid();
begin
  insert into public.ledgers (id, owner_id, name)
  values (v_ledger_id, new.id, '내 가계부');

  insert into public.accounts (id, ledger_id, name, kind)
  values (v_account_id, v_ledger_id, '현금', 'cash');

  insert into public.profiles (id, ledger_id, default_account_id)
  values (new.id, v_ledger_id, v_account_id);

  -- 모두 대분류다. sort_order는 종류(지출 · 수입)마다 10, 20, …으로 매긴다.
  insert into public.categories (id, ledger_id, kind, name, sort_order)
  select gen_random_uuid(), v_ledger_id, s.kind, n.name, (n.ord * 10)::integer
    from (values
           ('expense', array['식비', '카페·간식', '교통', '주거·통신', '생활', '쇼핑',
                             '의료·건강', '교육', '문화·여가', '경조사·선물', '금융·보험', '기타지출']),
           ('income',  array['급여', '용돈', '금융수익', '기타수입'])
         ) as s (kind, names)
   cross join lateral unnest(s.names) with ordinality as n (name, ord)
   order by s.kind, n.ord;

  return new;
end;
$$;

-- 트리거 함수는 직접 부를 일이 없다. Supabase가 기본으로 주는 실행 권한을 걷어 낸다.
revoke all on function public.handle_new_user() from public, anon, authenticated, service_role;

-- create or replace trigger는 auth.users의 TRIGGER 권한만 있으면 된다(drop trigger는 테이블 주인만 할 수 있다).
create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- delete_my_account: 계정 삭제
-- ---------------------------------------------------------------------------
create or replace function public.delete_my_account() returns void
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;

  -- 진행 중인 push가 끝나기를 기다린다. sync_push()와 같은 잠금 키다(0003).
  perform pg_advisory_xact_lock(hashtextextended('gagyebu.ledger:' || l.id::text, 0))
     from (select id from public.ledgers where owner_id = v_uid order by id) as l;

  -- 가계부를 지우면 딸린 행이 모두 지워진다(on delete cascade). sync_batches도 함께 지워진다.
  delete from public.ledgers where owner_id = v_uid;
  -- 인증 계정. 남아 있는 profiles 행도 여기서 지워진다.
  delete from auth.users where id = v_uid;
  -- 인증 계정이 지워지지 않았으면(이미 없거나 권한이 모자라 행이 보이지 않으면) 전부 되돌린다.
  -- 가계부만 지워지고 계정이 남는 반쪽 삭제를 막는다.
  if not found then
    raise exception 'auth user not found; nothing was deleted' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.delete_my_account() from public, anon, authenticated, service_role;
grant execute on function public.delete_my_account() to authenticated;

-- ---------------------------------------------------------------------------
-- purge_tombstones: 오래된 삭제 표시 정리
--  * 다른 행이 가리키지 않는 테이블부터 지운다.
--  * 분류와 자산은 남아 있는 행(살아 있든 삭제 표시든)이 하나라도 가리키면 남겨 둔다. 다음 정리 때 다시 본다.
--    FK가 없는 참조(parent_id, payment_account_id, default_account_id, 반복 거래 틀의 ID)도 참조로 센다.
--  * 오래된 push 결과(sync_batches)도 함께 지운다. 그 뒤에 같은 묶음이 다시 오면 새 묶음으로 판정한다
--    (이미 적용된 변경은 base_version이 맞지 않아 충돌 규칙으로 걸러진다).
--  * 지운 행 수를 테이블별로 돌려준다.
-- ---------------------------------------------------------------------------
create or replace function public.purge_tombstones(p_older_than interval default '90 days')
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
as $$
declare
  v_cutoff timestamptz;
  v_n      bigint;
  v_sum    bigint;
  v_out    jsonb := '{}';
begin
  if p_older_than is null or p_older_than < interval '0' then
    raise exception 'p_older_than must be a non-negative interval' using errcode = '22023';
  end if;
  v_cutoff := now() - p_older_than;

  -- 1. 다른 행이 가리키지 않는 테이블
  delete from public.transactions where deleted_at < v_cutoff;
  get diagnostics v_n = row_count;
  v_out := v_out || jsonb_build_object('transactions', v_n);

  delete from public.budgets where deleted_at < v_cutoff;
  get diagnostics v_n = row_count;
  v_out := v_out || jsonb_build_object('budgets', v_n);

  delete from public.category_rules where deleted_at < v_cutoff;
  get diagnostics v_n = row_count;
  v_out := v_out || jsonb_build_object('category_rules', v_n);

  delete from public.recurring_rules where deleted_at < v_cutoff;
  get diagnostics v_n = row_count;
  v_out := v_out || jsonb_build_object('recurring_rules', v_n);

  delete from public.monthly_summaries where deleted_at < v_cutoff;
  get diagnostics v_n = row_count;
  v_out := v_out || jsonb_build_object('monthly_summaries', v_n);

  -- 2. 분류. 소분류가 지워져야 대분류가 풀리므로 더 지울 것이 없을 때까지 되풀이한다.
  --    확인과 삭제 사이에 push가 새 참조를 커밋하면 FK가 삭제를 막는다. 그때는 이번 정리에서 건너뛴다.
  v_sum := 0;
  begin
    loop
      delete from public.categories c
       where c.deleted_at < v_cutoff
         and not exists (select 1 from public.transactions x where x.category_id = c.id)
         and not exists (select 1 from public.budgets x where x.category_id = c.id)
         and not exists (select 1 from public.category_rules x where x.category_id = c.id)
         and not exists (select 1 from public.categories x where x.parent_id = c.id and x.id <> c.id)
         and not exists (select 1 from public.recurring_rules x
                          where lower(x.template ->> 'category_id') = c.id::text);
      get diagnostics v_n = row_count;
      exit when v_n = 0;
      v_sum := v_sum + v_n;
    end loop;
  exception when foreign_key_violation then
    v_sum := 0;
    raise warning 'purge_tombstones: categories skipped this run: %', sqlerrm;
  end;
  v_out := v_out || jsonb_build_object('categories', v_sum);

  -- 3. 자산
  v_sum := 0;
  begin
    loop
      delete from public.accounts a
       where a.deleted_at < v_cutoff
         and not exists (select 1 from public.transactions x where x.account_id = a.id)
         and not exists (select 1 from public.transactions x where x.to_account_id = a.id)
         and not exists (select 1 from public.accounts x where x.payment_account_id = a.id and x.id <> a.id)
         and not exists (select 1 from public.profiles x where x.default_account_id = a.id)
         and not exists (select 1 from public.recurring_rules x
                          where lower(x.template ->> 'account_id') = a.id::text
                             or lower(x.template ->> 'to_account_id') = a.id::text);
      get diagnostics v_n = row_count;
      exit when v_n = 0;
      v_sum := v_sum + v_n;
    end loop;
  exception when foreign_key_violation then
    v_sum := 0;
    raise warning 'purge_tombstones: accounts skipped this run: %', sqlerrm;
  end;
  v_out := v_out || jsonb_build_object('accounts', v_sum);

  -- 4. 오래된 push 결과
  delete from public.sync_batches where created_at < v_cutoff;
  get diagnostics v_n = row_count;
  v_out := v_out || jsonb_build_object('sync_batches', v_n);

  return v_out;
end;
$$;

revoke all on function public.purge_tombstones(interval) from public, anon, authenticated, service_role;
grant execute on function public.purge_tombstones(interval) to service_role;
