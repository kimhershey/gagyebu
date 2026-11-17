-- 20_rls.sql
-- 행 수준 보안과 권한: 자기 가계부만 읽고, 직접 쓰지 못하고, anon은 아무것도 못 한다.
\ir _helpers.sql

-- ---------------------------------------------------------------------------
-- 준비: 사용자 A, B. 둘 다 동기화 테이블 9개 모두에 행을 갖게 한다.
-- ---------------------------------------------------------------------------
do $$
declare
  u    uuid;
  l    uuid;
  acc  uuid;
  cat  uuid;
  r    jsonb;
  name text;
begin
  foreach name in array array['a', 'b'] loop
    u := t.signup();
    l := t.ledger_of(u);
    acc := gen_random_uuid();
    cat := gen_random_uuid();
    perform t.set(name, u::text);
    perform t.set('acc_' || name, acc::text);

    perform t.login(u);
    r := t.push(l, jsonb_build_array(
      t.up('accounts', acc, 0, now(), '{"name": "월급통장", "kind": "bank"}'),
      t.up('categories', cat, 0, now(), '{"name": "간식", "kind": "expense"}'),
      t.up('transactions', gen_random_uuid(), 0, now(),
           jsonb_build_object('type', 'expense', 'occurred_on', '2026-11-16', 'amount', 4500,
                              'account_id', acc, 'category_id', cat, 'receiver', '편의점')),
      t.up('budgets', gen_random_uuid(), 0, now(),
           jsonb_build_object('month', '2026-11', 'category_id', cat, 'amount', 300000)),
      t.up('recurring_rules', gen_random_uuid(), 0, now(),
           jsonb_build_object('template', jsonb_build_object('type', 'expense', 'amount', 550000, 'account_id', acc),
                              'frequency', 'monthly', 'next_run_on', '2026-12-01')),
      t.up('category_rules', gen_random_uuid(), 0, now(),
           jsonb_build_object('pattern', '편의점', 'category_id', cat)),
      t.up('monthly_summaries', gen_random_uuid(), 0, now(),
           '{"month": "2026-10", "stats": {"expense": 1234500}}')));
    assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e),
      format('준비 push 실패: %s', r);
    perform t.logout();
    perform t.set('ledger_' || name, l::text);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 모든 테이블에 RLS가 켜져 있고, 정책은 조회용뿐이다.
-- ---------------------------------------------------------------------------
do $$
begin
  assert (select count(*) from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
             and not c.relrowsecurity) = 0,
    'public 스키마의 모든 테이블에 RLS가 켜져 있어야 한다';
  assert (select count(*) from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')) = 10,
    'public 스키마의 테이블은 10개다';
  assert (select count(*) from pg_policies where schemaname = 'public' and cmd <> 'SELECT') = 0,
    '쓰기 정책이 있으면 안 된다';
  assert (select count(*) from pg_policies where schemaname = 'public' and roles <> '{authenticated}') = 0,
    '정책은 authenticated에게만 건다';
  assert (select count(*) from pg_policies where schemaname = 'public') = 9, '조회 정책은 테이블마다 1개(9개)';
  assert (select count(*) from pg_policies where schemaname = 'public' and tablename = 'sync_batches') = 0,
    'sync_batches에는 정책이 없다';
end $$;

-- ---------------------------------------------------------------------------
-- 권한표: authenticated는 9개 테이블 조회만, anon은 아무것도 없다. 함수 실행 권한도 정해진 역할뿐이다.
-- ---------------------------------------------------------------------------
do $$
declare
  tbl       text;
  priv      text;
  fn        text;
  who       text;
  role_name text;
begin
  foreach tbl in array array['ledgers', 'profiles', 'accounts', 'categories', 'transactions', 'budgets',
                             'recurring_rules', 'category_rules', 'monthly_summaries', 'sync_batches'] loop
    foreach priv in array array['select', 'insert', 'update', 'delete', 'truncate', 'references', 'trigger'] loop
      assert not has_table_privilege('anon', 'public.' || tbl, priv), format('anon %s on %s', priv, tbl);
      if priv = 'select' and tbl <> 'sync_batches' then
        assert has_table_privilege('authenticated', 'public.' || tbl, priv), format('authenticated select on %s', tbl);
      else
        assert not has_table_privilege('authenticated', 'public.' || tbl, priv),
          format('authenticated %s on %s', priv, tbl);
      end if;
    end loop;
  end loop;

  assert not has_sequence_privilege('anon', 'public.server_seq', 'usage'), 'anon은 시퀀스를 못 쓴다';
  assert not has_sequence_privilege('authenticated', 'public.server_seq', 'usage'), 'authenticated도 시퀀스를 못 쓴다';
  assert not has_sequence_privilege('authenticated', 'public.server_seq', 'select'), '시퀀스 값도 못 읽는다';

  -- 함수: sync_push · sync_pull · delete_my_account는 authenticated만, purge_tombstones는 service_role만
  for fn, who in
    select * from (values
      ('public.sync_push(uuid,uuid,uuid,jsonb)', 'authenticated'),
      ('public.sync_pull(uuid,bigint,integer)',  'authenticated'),
      ('public.delete_my_account()',             'authenticated'),
      ('public.purge_tombstones(interval)',      'service_role'),
      ('public.handle_new_user()',               '(없음)')) as x (fn, who)
  loop
    foreach role_name in array array['anon', 'authenticated', 'service_role'] loop
      assert has_function_privilege(role_name, fn, 'execute') = (role_name = who),
        format('%s의 실행 권한은 %s에게만 있어야 한다(%s를 확인)', fn, who, role_name);
    end loop;
    -- PUBLIC에게도 열려 있지 않다.
    assert not exists (
      select 1 from pg_proc p, aclexplode(p.proacl) a
       where p.oid = fn::regprocedure and a.grantee = 0 and a.privilege_type = 'EXECUTE'),
      format('%s가 PUBLIC에게 열려 있다', fn);
  end loop;

  -- 공개 함수는 모두 SECURITY DEFINER이고 search_path를 고정했다.
  assert (select count(*) from pg_proc p
           where p.pronamespace = 'public'::regnamespace
             and (not p.prosecdef
                  or not exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%'))) = 0,
    'public의 함수는 모두 SECURITY DEFINER이고 search_path가 고정돼 있어야 한다';
end $$;

-- ---------------------------------------------------------------------------
-- 조회: 자기 가계부의 행만 보인다. 남의 행은 어느 테이블에서도 안 보인다.
-- 가장은 README에 적은 방식 그대로 쓴다(set local role + request.jwt.claims).
-- ---------------------------------------------------------------------------
select t.get('a') as user_a, t.get('b') as user_b \gset

begin;
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :'user_b')::text, true);
do $$
declare
  a   uuid := t.id('a');
  b   uuid := t.id('b');
  tbl text;
  n   bigint;
begin
  assert current_user = 'authenticated' and auth.uid() = b, 'B로 가장했다';

  -- B의 눈: ledgers는 자기 것 1개뿐
  assert (select count(*) from public.ledgers) = 1, 'B는 가계부를 1개만 본다';
  assert (select count(*) from public.ledgers where owner_id = a) = 0, 'B는 A의 가계부를 못 본다';
  assert (select count(*) from public.profiles) = 1 and (select id from public.profiles) = b, 'B는 자기 프로필만 본다';

  foreach tbl in array array['profiles', 'accounts', 'categories', 'transactions', 'budgets',
                             'recurring_rules', 'category_rules', 'monthly_summaries'] loop
    execute format('select count(*) from public.%I where ledger_id <> (select id from public.ledgers)', tbl) into n;
    assert n = 0, format('B에게 남의 %s 행이 %s개 보인다', tbl, n);
    execute format('select count(*) from public.%I', tbl) into n;
    assert n >= 1, format('B는 자기 %s 행을 본다', tbl);
  end loop;

  -- A의 행을 ID로 콕 집어도 안 보인다.
  assert t.row_of('accounts', t.id('acc_a')) is null, 'B는 A의 자산을 ID로도 못 읽는다';
  assert t.row_of('accounts', t.id('acc_b')) is not null, 'B는 자기 자산을 읽는다';

  -- sync_batches는 읽을 권한이 없다.
  assert t.sqlstate_of('select count(*) from public.sync_batches') = '42501', 'sync_batches 조회는 거부된다';
end $$;
commit;

-- A의 눈으로도 같은지 본다(대칭).
do $$
declare
  a   uuid := t.id('a');
  tbl text;
  n   bigint;
  la  uuid := t.ledger_of(t.id('a'));
  lb  uuid := t.ledger_of(t.id('b'));
begin
  perform t.login(a);
  foreach tbl in array array['profiles', 'accounts', 'categories', 'transactions', 'budgets',
                             'recurring_rules', 'category_rules', 'monthly_summaries'] loop
    execute format('select count(*) from public.%I where ledger_id = $1', tbl) into n using lb;
    assert n = 0, format('A에게 B의 %s 행이 %s개 보인다', tbl, n);
    execute format('select count(*) from public.%I where ledger_id = $1', tbl) into n using la;
    assert n >= 1, format('A는 자기 %s 행을 본다', tbl);
  end loop;
  assert (select count(*) from public.ledgers where id = lb) = 0, 'A는 B의 가계부를 못 본다';
end $$;

-- sub가 없는 토큰(authenticated인데 auth.uid()가 null)은 아무것도 못 본다.
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"role": "authenticated"}', true);
  assert auth.uid() is null;
  assert (select count(*) from public.ledgers) = 0 and (select count(*) from public.transactions) = 0,
    'sub가 없으면 아무 행도 안 보인다';
  assert t.sqlstate_of(format('select public.sync_pull(%L, 0)', t.id('ledger_a'))) = '42501',
    'sub가 없으면 sync_pull도 42501';
end $$;

-- ---------------------------------------------------------------------------
-- 직접 쓰기: authenticated의 insert · update · delete는 권한 단계에서 거부된다.
-- ---------------------------------------------------------------------------
do $$
declare
  a   uuid := t.id('a');
  tbl text;
begin
  perform t.login(a);
  foreach tbl in array array['ledgers', 'profiles', 'accounts', 'categories', 'transactions', 'budgets',
                             'recurring_rules', 'category_rules', 'monthly_summaries', 'sync_batches'] loop
    assert t.sqlstate_of(format('insert into public.%I default values', tbl)) = '42501', format('insert %s', tbl);
    assert t.sqlstate_of(format('update public.%I set created_at = now()', tbl)) = '42501', format('update %s', tbl);
    assert t.sqlstate_of(format('delete from public.%I', tbl)) = '42501', format('delete %s', tbl);
    assert t.sqlstate_of(format('truncate public.%I cascade', tbl)) = '42501', format('truncate %s', tbl);
  end loop;
  assert t.sqlstate_of($q$select nextval('public.server_seq')$q$) = '42501', '시퀀스를 직접 당길 수 없다';
  assert t.sqlstate_of($q$select setval('public.server_seq', 1)$q$) = '42501', '시퀀스를 되돌릴 수 없다';
end $$;

-- ---------------------------------------------------------------------------
-- 권한이 실수로 다시 열려도 RLS가 막는다(이중 방어). 트랜잭션 안에서 권한을 열어 보고 되돌린다.
-- ---------------------------------------------------------------------------
begin;
grant select, insert, update, delete on table
  public.ledgers, public.profiles, public.accounts, public.categories, public.transactions,
  public.budgets, public.recurring_rules, public.category_rules, public.monthly_summaries,
  public.sync_batches
to anon, authenticated;

do $$
declare
  a   uuid := t.id('a');
  la  uuid := t.ledger_of(t.id('a'));
  lb  uuid := t.ledger_of(t.id('b'));
  tbl text;
  n   bigint;
begin
  -- A: 자기 가계부에 넣는 것조차 정책이 없어 거부된다.
  perform t.login(a);
  assert t.sqlstate_of(format(
    $q$insert into public.accounts (id, ledger_id, name, kind) values (gen_random_uuid(), %L, '몰래', 'cash')$q$, la))
    = '42501', '자기 가계부라도 직접 insert는 RLS가 막는다';
  assert t.sqlstate_of(format(
    $q$insert into public.accounts (id, ledger_id, name, kind) values (gen_random_uuid(), %L, '몰래', 'cash')$q$, lb))
    = '42501', '남의 가계부에 insert는 RLS가 막는다';
  assert t.sqlstate_of(format(
    $q$insert into public.ledgers (id, owner_id, name) values (gen_random_uuid(), %L, '몰래')$q$, a))
    = '42501', '가계부를 직접 만들 수 없다';

  -- update · delete는 보이는 행이 있어도 0건이다.
  foreach tbl in array array['ledgers', 'profiles', 'accounts', 'categories', 'transactions', 'budgets',
                             'recurring_rules', 'category_rules', 'monthly_summaries', 'sync_batches'] loop
    execute format('update public.%I set created_at = now()', tbl);
    get diagnostics n = row_count;
    assert n = 0, format('update %s가 %s건 적용됐다', tbl, n);
    execute format('delete from public.%I', tbl);
    get diagnostics n = row_count;
    assert n = 0, format('delete %s가 %s건 적용됐다', tbl, n);
  end loop;
  assert (select count(*) from public.sync_batches) = 0, 'sync_batches는 권한이 있어도 한 행도 안 보인다';

  -- anon: 권한이 열려도 한 행도 안 보이고 쓰지도 못한다.
  perform t.logout();
  perform t.login_anon();
  foreach tbl in array array['ledgers', 'profiles', 'accounts', 'categories', 'transactions', 'budgets',
                             'recurring_rules', 'category_rules', 'monthly_summaries', 'sync_batches'] loop
    execute format('select count(*) from public.%I', tbl) into n;
    assert n = 0, format('anon에게 %s 행이 %s개 보인다', tbl, n);
    execute format('delete from public.%I', tbl);
    get diagnostics n = row_count;
    assert n = 0, format('anon의 delete %s가 %s건 적용됐다', tbl, n);
  end loop;
  assert t.sqlstate_of(format(
    $q$insert into public.accounts (id, ledger_id, name, kind) values (gen_random_uuid(), %L, '몰래', 'cash')$q$, la))
    = '42501', 'anon의 insert는 RLS가 막는다';
end $$;
rollback;

-- 되돌린 뒤 실제 행 수는 그대로다(위에서 아무것도 지워지지 않았다).
do $$
begin
  assert (select count(*) from public.accounts where ledger_id = t.ledger_of(t.id('a'))) = 2, 'A의 자산 2개(현금 + 월급통장)';
  assert (select count(*) from public.transactions where ledger_id = t.ledger_of(t.id('a'))) = 1, 'A의 거래 1개';
end $$;

-- ---------------------------------------------------------------------------
-- anon: 테이블도 함수도 쓸 수 없다.
-- ---------------------------------------------------------------------------
begin;
set local role anon;
select set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
do $$
declare
  la  uuid := t.id('ledger_a');
  tbl text;
begin
  assert current_user = 'anon' and auth.uid() is null;
  foreach tbl in array array['ledgers', 'profiles', 'accounts', 'categories', 'transactions', 'budgets',
                             'recurring_rules', 'category_rules', 'monthly_summaries', 'sync_batches'] loop
    assert t.sqlstate_of(format('select count(*) from public.%I', tbl)) = '42501', format('anon select %s', tbl);
    assert t.sqlstate_of(format('insert into public.%I default values', tbl)) = '42501', format('anon insert %s', tbl);
    assert t.sqlstate_of(format('update public.%I set created_at = now()', tbl)) = '42501', format('anon update %s', tbl);
    assert t.sqlstate_of(format('delete from public.%I', tbl)) = '42501', format('anon delete %s', tbl);
  end loop;
  assert t.sqlstate_of(format('select public.sync_pull(%L, 0)', la)) = '42501', 'anon은 sync_pull을 못 부른다';
  assert t.sqlstate_of(format($q$select public.sync_push(%L, gen_random_uuid(), gen_random_uuid(), '[]')$q$, la))
    = '42501', 'anon은 sync_push를 못 부른다';
  assert t.sqlstate_of('select public.delete_my_account()') = '42501', 'anon은 delete_my_account를 못 부른다';
  assert t.sqlstate_of('select public.purge_tombstones()') = '42501', 'anon은 purge_tombstones를 못 부른다';
end $$;
rollback;

-- ---------------------------------------------------------------------------
-- 남의 가계부로 sync_push · sync_pull을 부르면 42501. 없는 가계부와 구별되지 않는다.
-- ---------------------------------------------------------------------------
do $$
declare
  b   uuid := t.id('b');
  la  uuid := t.ledger_of(t.id('a'));
  lb  uuid := t.ledger_of(t.id('b'));
  no  uuid := gen_random_uuid();
  n1  bigint;
  q_pull text := 'select public.sync_pull(%L, 0)';
  q_push text := $q$select public.sync_push(%L, gen_random_uuid(), gen_random_uuid(),
                   jsonb_build_array(t.up('accounts', gen_random_uuid(), 0, now(), '{"name": "침입", "kind": "cash"}')))$q$;
begin
  select count(*) into n1 from public.accounts where ledger_id = la;

  perform t.login(b);
  assert t.sqlstate_of(format(q_pull, la)) = '42501', 'B가 A의 가계부를 pull하면 42501';
  assert t.sqlstate_of(format(q_push, la)) = '42501', 'B가 A의 가계부에 push하면 42501';
  assert t.sqlstate_of(format(q_pull, no)) = '42501', '없는 가계부도 42501';
  assert t.sqlstate_of(format(q_push, no)) = '42501', '없는 가계부도 42501';
  assert t.errmsg_of(format(q_pull, la)) = t.errmsg_of(format(q_pull, no)), '남의 가계부와 없는 가계부의 오류가 같다';
  assert t.errmsg_of(format(q_push, la)) = t.errmsg_of(format(q_push, no)), '남의 가계부와 없는 가계부의 오류가 같다';
  assert t.sqlstate_of('select public.sync_pull(null, 0)') = '42501', '가계부 ID가 null이어도 42501';
  -- 자기 가계부는 된다.
  assert t.sqlstate_of(format(q_pull, lb)) = '00000', 'B는 자기 가계부를 pull한다';

  -- 서비스 전용 함수는 사용자가 부를 수 없다.
  assert t.sqlstate_of('select public.purge_tombstones()') = '42501', 'authenticated는 purge_tombstones를 못 부른다';

  perform t.logout();
  assert (select count(*) from public.accounts where ledger_id = la) = n1, 'A의 자산 수는 그대로다';
  assert (select count(*) from public.sync_batches where ledger_id = la) = 1, 'A의 가계부에 남의 묶음이 기록되지 않았다';
end $$;
