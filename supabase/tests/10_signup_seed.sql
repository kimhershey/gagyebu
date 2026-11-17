-- 10_signup_seed.sql
-- 가입 시 시드: auth.users에 행이 생기면 가계부 1개, 프로필, 기본 분류 16개, 현금 자산이 만들어진다.
\ir _helpers.sql

-- ---------------------------------------------------------------------------
-- 가입은 GoTrue의 역할(supabase_auth_admin)이 한다. 이 역할은 public 테이블에 아무 권한이 없다.
-- 그래도 시드가 만들어져야 한다(handle_new_user가 SECURITY DEFINER여야 한다).
-- ---------------------------------------------------------------------------
do $$
declare
  v_user uuid := gen_random_uuid();
begin
  assert not has_table_privilege('supabase_auth_admin', 'public.ledgers', 'insert'),
    'supabase_auth_admin은 public.ledgers에 쓸 권한이 없어야 시험이 뜻을 가진다';

  perform set_config('role', 'supabase_auth_admin', true);
  insert into auth.users (id, email) values (v_user, 'seed@test.local');
  perform set_config('role', 'none', true);

  perform t.set('u', v_user::text);
end $$;

do $$
declare
  u uuid := t.id('u');
  l record;
  p record;
  a record;
  c_dot constant text := chr(183);  -- 가운뎃점 U+00B7
  v_expense text[];
  v_income  text[];
begin
  -- 가계부 1개
  assert (select count(*) from public.ledgers where owner_id = u) = 1, '가계부는 1개여야 한다';
  select * into l from public.ledgers where owner_id = u;
  assert l.name = '내 가계부', format('가계부 이름: %s', l.name);
  assert l.currency = 'KRW', '통화 기본값은 KRW';
  assert l.version = 1 and l.deleted_at is null, '가계부 version 1, 삭제 표시 없음';

  -- 현금 자산 1개
  assert (select count(*) from public.accounts where ledger_id = l.id) = 1, '자산은 1개여야 한다';
  select * into a from public.accounts where ledger_id = l.id;
  assert a.name = '현금' and a.kind = 'cash', format('현금 자산: %s / %s', a.name, a.kind);
  assert a.version = 1 and a.deleted_at is null and a.opening_balance = 0, '현금 자산의 기본값';

  -- 프로필
  assert (select count(*) from public.profiles where id = u) = 1, '프로필은 1개여야 한다';
  select * into p from public.profiles where id = u;
  assert p.ledger_id = l.id, '프로필이 가계부를 가리킨다';
  assert p.default_account_id = a.id, 'default_account_id는 현금 자산이어야 한다';
  assert p.month_start_day = 1, 'month_start_day 기본값은 1';

  -- 기본 분류 16개: 이름 · 순서 · sort_order
  assert (select count(*) from public.categories where ledger_id = l.id) = 16, '분류는 16개여야 한다';
  assert (select count(*) from public.categories
           where ledger_id = l.id and (parent_id is not null or deleted_at is not null or version <> 1)) = 0,
    '분류는 모두 대분류이고 version 1이다';

  select array_agg(name order by sort_order) into v_expense
    from public.categories where ledger_id = l.id and kind = 'expense';
  select array_agg(name order by sort_order) into v_income
    from public.categories where ledger_id = l.id and kind = 'income';

  assert v_expense = array[
      '식비', '카페' || c_dot || '간식', '교통', '주거' || c_dot || '통신', '생활', '쇼핑',
      '의료' || c_dot || '건강', '교육', '문화' || c_dot || '여가', '경조사' || c_dot || '선물',
      '금융' || c_dot || '보험', '기타지출'],
    format('지출 분류: %s', v_expense);
  assert v_income = array['급여', '용돈', '금융수익', '기타수입'], format('수입 분류: %s', v_income);

  assert (select array_agg(sort_order order by sort_order) from public.categories
           where ledger_id = l.id and kind = 'expense')
         = array[10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120], '지출 sort_order는 10, 20, …, 120';
  assert (select array_agg(sort_order order by sort_order) from public.categories
           where ledger_id = l.id and kind = 'income')
         = array[10, 20, 30, 40], '수입 sort_order는 10, 20, 30, 40';

  -- server_seq는 행마다 다르다(전역 시퀀스에서 받는다).
  assert (select count(distinct s) from (
            select server_seq as s from public.ledgers where id = l.id
            union all select server_seq from public.profiles where ledger_id = l.id
            union all select server_seq from public.accounts where ledger_id = l.id
            union all select server_seq from public.categories where ledger_id = l.id) x) = 19,
    '시드 19행의 server_seq가 모두 달라야 한다';
end $$;

-- ---------------------------------------------------------------------------
-- 새 기기의 첫 pull: 시드 19행을 server_seq 순서로 받는다.
-- ---------------------------------------------------------------------------
do $$
declare
  u uuid := t.id('u');
  l uuid := t.ledger_of(u);
  r jsonb;
begin
  perform t.login(u);
  r := public.sync_pull(l, 0);
  assert jsonb_array_length(r -> 'changes') = 19, format('첫 pull은 19행: %s', jsonb_array_length(r -> 'changes'));
  assert not (r ->> 'has_more')::boolean, '한 번에 다 받는다';
  assert (select count(*) from jsonb_array_elements(r -> 'changes') c where c ->> 'table' = 'categories') = 16, '분류 16';
  assert (select count(*) from jsonb_array_elements(r -> 'changes') c where c ->> 'table' = 'ledgers') = 1, '가계부 1';
  assert (select count(*) from jsonb_array_elements(r -> 'changes') c where c ->> 'table' = 'profiles') = 1, '프로필 1';
  assert (select count(*) from jsonb_array_elements(r -> 'changes') c where c ->> 'table' = 'accounts') = 1, '자산 1';
end $$;

-- ---------------------------------------------------------------------------
-- 사용자마다 따로 만들어진다.
-- ---------------------------------------------------------------------------
do $$
declare
  u  uuid := t.id('u');
  u2 uuid := t.signup();
begin
  assert t.ledger_of(u2) is not null and t.ledger_of(u2) <> t.ledger_of(u), '두 번째 사용자는 다른 가계부를 받는다';
  assert (select count(*) from public.categories where ledger_id = t.ledger_of(u2)) = 16, '두 번째 사용자도 분류 16개';
  assert (select count(*) from public.categories where ledger_id = t.ledger_of(u)) = 16, '첫 사용자의 분류는 그대로';
  assert (select count(*) from public.ledgers where owner_id in (u, u2)) = 2, '사용자당 가계부 1개';
end $$;

-- ---------------------------------------------------------------------------
-- 트리거 함수는 클라이언트가 직접 부를 수 없다.
-- ---------------------------------------------------------------------------
do $$
declare
  u uuid := t.id('u');
begin
  assert not has_function_privilege('anon', 'public.handle_new_user()', 'execute'), 'anon 실행 권한 없음';
  assert not has_function_privilege('authenticated', 'public.handle_new_user()', 'execute'), 'authenticated 실행 권한 없음';
  assert not has_function_privilege('service_role', 'public.handle_new_user()', 'execute'), 'service_role 실행 권한 없음';
  assert (select prosecdef from pg_proc where oid = 'public.handle_new_user()'::regprocedure), 'SECURITY DEFINER';

  perform t.login(u);
  assert t.sqlstate_of('select public.handle_new_user()') <> '00000', '직접 호출은 실패해야 한다';
end $$;
