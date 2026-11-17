-- 70_lifecycle.sql
-- 계정 삭제(delete_my_account)와 오래된 삭제 표시 정리(purge_tombstones).
\ir _helpers.sql

-- 사용자의 가계부에 9개 테이블 모두의 행을 만든다(삭제 표시가 있는 행도 섞는다).
create or replace function t.fill_ledger(p_user uuid) returns void
language plpgsql as $$
declare
  l    uuid := t.ledger_of(p_user);
  acc1 uuid := gen_random_uuid();
  acc2 uuid := gen_random_uuid();
  cat  uuid := gen_random_uuid();
  tx1  uuid := gen_random_uuid();
  tx2  uuid := gen_random_uuid();
  r    jsonb;
begin
  perform t.login(p_user);
  r := t.push(l, jsonb_build_array(
    t.up('accounts', acc1, 0, now(), t.acc('통장')),
    t.up('accounts', acc2, 0, now(), '{"name": "카드", "kind": "credit_card"}' || jsonb_build_object('payment_account_id', acc1)),
    t.up('categories', cat, 0, now(), '{"name": "간식", "kind": "expense"}'),
    t.up('transactions', tx1, 0, now(), t.tx(acc2, '과자') || jsonb_build_object('category_id', cat)),
    t.up('transactions', tx2, 0, now(), t.tx(acc1, '카드값') || jsonb_build_object('type', 'transfer', 'to_account_id', acc2)),
    t.up('budgets', gen_random_uuid(), 0, now(), jsonb_build_object('month', '2026-11', 'amount', 100000, 'category_id', cat)),
    t.up('recurring_rules', gen_random_uuid(), 0, now(), jsonb_build_object(
      'template', jsonb_build_object('type', 'expense', 'amount', 9900, 'account_id', acc2),
      'frequency', 'monthly', 'next_run_on', '2026-12-01')),
    t.up('category_rules', gen_random_uuid(), 0, now(), jsonb_build_object('pattern', '편의점', 'category_id', cat)),
    t.up('monthly_summaries', gen_random_uuid(), 0, now(), '{"month": "2026-10", "stats": {}}')));
  assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e), format('%s', r);
  -- 삭제 표시: 거래 하나와, 그 거래가 가리키는 자산
  r := t.push(l, jsonb_build_array(t.del('transactions', tx2, 1, now()), t.del('accounts', acc2, 1, now())));
  assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e), format('%s', r);
  perform t.logout();
end $$;

-- 가계부에 딸린 행 수를 테이블별로 센다(주인의 눈으로, RLS 없이).
create or replace function t.ledger_counts(p_ledger uuid) returns jsonb
language plpgsql as $$
declare
  tbl text;
  n   bigint;
  out jsonb := '{}';
begin
  foreach tbl in array array['profiles', 'accounts', 'categories', 'transactions', 'budgets', 'recurring_rules',
                             'category_rules', 'monthly_summaries', 'sync_batches'] loop
    execute format('select count(*) from public.%I where ledger_id = $1', tbl) into n using p_ledger;
    out := out || jsonb_build_object(tbl, n);
  end loop;
  select count(*) into n from public.ledgers where id = p_ledger;
  return out || jsonb_build_object('ledgers', n);
end $$;

-- ===========================================================================
-- delete_my_account
-- ===========================================================================
do $$
declare
  a uuid := t.signup();
  b uuid := t.signup();
begin
  perform t.set('a', a::text);
  perform t.set('la', t.ledger_of(a)::text);
  perform t.set('b', b::text);
  perform t.set('lb', t.ledger_of(b)::text);
  perform t.fill_ledger(a);
  perform t.fill_ledger(b);
  perform t.set('counts_b', t.ledger_counts(t.id('lb'))::text);

  -- 지우기 전: A의 가계부에는 모든 테이블에 행이 있다.
  assert (select bool_and(v::bigint >= 1) from jsonb_each_text(t.ledger_counts(t.id('la'))) as e (k, v)),
    format('준비가 덜 됐다: %s', t.ledger_counts(t.id('la')));
end $$;

-- 로그인하지 않으면 지울 수 없다.
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"role": "authenticated"}', true);
  assert t.sqlstate_of('select public.delete_my_account()') = '42501', 'sub가 없으면 42501';
  perform t.logout();
  assert (select count(*) from auth.users where id in (t.id('a'), t.id('b'))) = 2, '아무도 지워지지 않았다';
end $$;

-- A가 자기 계정을 지운다.
do $$
declare
  a  uuid := t.id('a');
  b  uuid := t.id('b');
  la uuid := t.id('la');
  lb uuid := t.id('lb');
  c  jsonb;
begin
  perform t.login(a);
  perform public.delete_my_account();
  perform t.logout();

  -- A의 행은 어느 테이블에도 없다. 인증 계정도 없다.
  c := t.ledger_counts(la);
  assert (select bool_and(v::bigint = 0) from jsonb_each_text(c) as e (k, v)), format('A의 행이 남았다: %s', c);
  assert (select count(*) from public.profiles where id = a) = 0, 'A의 프로필이 남았다';
  assert (select count(*) from public.ledgers where owner_id = a) = 0, 'A의 가계부가 남았다';
  assert (select count(*) from auth.users where id = a) = 0, 'A의 인증 계정이 남았다';

  -- B는 그대로다.
  assert t.ledger_counts(lb) = t.get('counts_b')::jsonb,
    format('B의 행 수가 바뀌었다: %s → %s', t.get('counts_b'), t.ledger_counts(lb));
  assert (select count(*) from auth.users where id = b) = 1 and (select count(*) from public.profiles where id = b) = 1;

  -- 지워진 계정의 토큰(만료 전)으로는 아무것도 못 한다.
  perform t.login(a);
  assert t.sqlstate_of(format('select public.sync_pull(%L, 0)', la)) = '42501', '지워진 계정의 pull';
  assert t.sqlstate_of(format($q$select public.sync_push(%L, %L, gen_random_uuid(), '[]')$q$, la, t.dev(1))) = '42501',
    '지워진 계정의 push';
  assert (select count(*) from public.ledgers) = 0 and (select count(*) from public.transactions) = 0, '보이는 행이 없다';
  -- 이미 지운 계정으로 또 부르면 지울 것이 없다는 오류다. 다른 것은 건드리지 않는다.
  assert t.sqlstate_of('select public.delete_my_account()') = 'P0002', '이미 지운 계정을 또 지우면 P0002';
  perform t.logout();
  assert (select count(*) from auth.users where id = b) = 1, 'B는 여전히 있다';
  assert t.ledger_counts(lb) = t.get('counts_b')::jsonb, 'B의 행은 그대로다';
end $$;

-- 인증 계정을 지우지 못하면 가계부도 지워지지 않는다(반쪽 삭제를 막는다).
-- 함수 주인(postgres)이 auth.users의 행을 지울 권한을 잃은 상황을 트랜잭션 안에서 만들어 보고 되돌린다.
begin;
set local role supabase_auth_admin;
revoke delete on auth.users from postgres;
reset role;
do $$
declare
  b  uuid := t.id('b');
  lb uuid := t.id('lb');
begin
  perform t.login(b);
  assert t.sqlstate_of('select public.delete_my_account()') = '42501', '인증 계정을 못 지우면 실패해야 한다';
  perform t.logout();
  assert (select count(*) from public.ledgers where id = lb) = 1 and t.ledger_counts(lb) = t.get('counts_b')::jsonb,
    '실패한 계정 삭제가 가계부를 지웠다';
end $$;
rollback;

-- 그 뒤에 가입한 사용자는 새 가계부를 받는다(옛 행과 섞이지 않는다).
do $$
declare
  a2 uuid := t.signup();
begin
  assert t.ledger_of(a2) is not null and t.ledger_of(a2) <> t.id('la');
  assert (select count(*) from public.transactions where ledger_id = t.ledger_of(a2)) = 0;
  assert (select count(*) from public.categories where ledger_id = t.ledger_of(a2)) = 16;
end $$;

-- ===========================================================================
-- purge_tombstones
-- ===========================================================================
-- 준비: 사용자 P의 가계부에 여러 처지의 삭제 표시를 만든다. 이름이 곧 기대 결과다.
--   purge_*  지워져야 한다        keep_*  남아야 한다
do $$
declare
  p uuid := t.signup();
  l uuid := t.ledger_of(p);
  k text;
  r jsonb;
  old_ids uuid[];
begin
  perform t.set('p', p::text);
  perform t.set('lp', l::text);
  foreach k in array array[
    -- 자산
    'acc_live', 'acc_purge_free', 'acc_keep_recent', 'acc_keep_ref_live_tx', 'acc_keep_ref_to_account',
    'acc_keep_ref_recent_tomb_tx', 'acc_purge_ref_old_tomb_tx', 'acc_keep_payment', 'acc_keep_default',
    'acc_keep_template', 'acc_live_card',
    -- 분류
    'cat_live', 'cat_purge_free', 'cat_keep_recent', 'cat_keep_ref_tx', 'cat_keep_ref_budget', 'cat_keep_ref_rule',
    'cat_purge_parent', 'cat_purge_child', 'cat_keep_parent', 'cat_live_child', 'cat_keep_template',
    -- 거래
    'tx_live', 'tx_live_transfer', 'tx_purge_old', 'tx_keep_recent', 'tx_purge_old_ref',
    -- 그 밖
    'budget_live', 'budget_purge', 'budget_keep_recent', 'rule_live', 'rule_purge', 'rule_keep_recent',
    'recur_live', 'recur_purge', 'recur_keep_recent', 'sum_live', 'sum_purge', 'sum_keep_recent'] loop
    perform t.set(k, gen_random_uuid()::text);
  end loop;

  perform t.login(p);
  r := t.push(l, jsonb_build_array(
    t.up('accounts', t.id('acc_live'), 0, now(), t.acc('살아 있는 통장')),
    t.up('accounts', t.id('acc_purge_free'), 0, now(), t.acc('아무도 안 가리킴')),
    t.up('accounts', t.id('acc_keep_recent'), 0, now(), t.acc('최근에 지움')),
    t.up('accounts', t.id('acc_keep_ref_live_tx'), 0, now(), t.acc('살아 있는 거래가 가리킴')),
    t.up('accounts', t.id('acc_keep_ref_to_account'), 0, now(), t.acc('이체가 받는 쪽으로 가리킴')),
    t.up('accounts', t.id('acc_keep_ref_recent_tomb_tx'), 0, now(), t.acc('최근에 지운 거래가 가리킴')),
    t.up('accounts', t.id('acc_purge_ref_old_tomb_tx'), 0, now(), t.acc('오래전에 지운 거래만 가리킴')),
    t.up('accounts', t.id('acc_keep_payment'), 0, now(), t.acc('카드의 결제 계좌')),
    t.up('accounts', t.id('acc_keep_default'), 0, now(), t.acc('프로필의 기본 자산')),
    t.up('accounts', t.id('acc_keep_template'), 0, now(), t.acc('반복 거래 틀이 가리킴')),
    t.up('accounts', t.id('acc_live_card'), 0, now(),
         '{"name": "살아 있는 카드", "kind": "credit_card"}' || jsonb_build_object('payment_account_id', t.id('acc_keep_payment'))),
    t.up('profiles', p, 1, now(), jsonb_build_object('default_account_id', t.id('acc_keep_default'))),

    t.up('categories', t.id('cat_live'), 0, now(), '{"name": "살아 있는 분류", "kind": "expense"}'),
    t.up('categories', t.id('cat_purge_free'), 0, now(), '{"name": "아무도 안 가리킴", "kind": "expense"}'),
    t.up('categories', t.id('cat_keep_recent'), 0, now(), '{"name": "최근에 지움", "kind": "expense"}'),
    t.up('categories', t.id('cat_keep_ref_tx'), 0, now(), '{"name": "거래가 가리킴", "kind": "expense"}'),
    t.up('categories', t.id('cat_keep_ref_budget'), 0, now(), '{"name": "예산이 가리킴", "kind": "expense"}'),
    t.up('categories', t.id('cat_keep_ref_rule'), 0, now(), '{"name": "규칙이 가리킴", "kind": "expense"}'),
    t.up('categories', t.id('cat_purge_parent'), 0, now(), '{"name": "지운 대분류", "kind": "expense"}'),
    t.up('categories', t.id('cat_purge_child'), 0, now(),
         '{"name": "지운 소분류", "kind": "expense"}' || jsonb_build_object('parent_id', t.id('cat_purge_parent'))),
    t.up('categories', t.id('cat_keep_parent'), 0, now(), '{"name": "소분류가 살아 있는 대분류", "kind": "expense"}'),
    t.up('categories', t.id('cat_live_child'), 0, now(),
         '{"name": "살아 있는 소분류", "kind": "expense"}' || jsonb_build_object('parent_id', t.id('cat_keep_parent'))),
    t.up('categories', t.id('cat_keep_template'), 0, now(), '{"name": "반복 거래 틀이 가리킴", "kind": "expense"}'),

    t.up('transactions', t.id('tx_live'), 0, now(),
         t.tx(t.id('acc_keep_ref_live_tx'), '살아 있는 거래') || jsonb_build_object('category_id', t.id('cat_keep_ref_tx'))),
    t.up('transactions', t.id('tx_live_transfer'), 0, now(),
         t.tx(t.id('acc_live'), '살아 있는 이체') || jsonb_build_object('type', 'transfer', 'to_account_id', t.id('acc_keep_ref_to_account'))),
    t.up('transactions', t.id('tx_purge_old'), 0, now(), t.tx(t.id('acc_live'), '오래전에 지운 거래')),
    t.up('transactions', t.id('tx_keep_recent'), 0, now(), t.tx(t.id('acc_keep_ref_recent_tomb_tx'), '최근에 지운 거래')),
    t.up('transactions', t.id('tx_purge_old_ref'), 0, now(), t.tx(t.id('acc_purge_ref_old_tomb_tx'), '오래전에 지운 거래 2')),

    t.up('budgets', t.id('budget_live'), 0, now(), jsonb_build_object('month', '2026-11', 'amount', 1, 'category_id', t.id('cat_keep_ref_budget'))),
    t.up('budgets', t.id('budget_purge'), 0, now(), '{"month": "2026-08", "amount": 1}'),
    t.up('budgets', t.id('budget_keep_recent'), 0, now(), '{"month": "2026-09", "amount": 1}'),
    t.up('category_rules', t.id('rule_live'), 0, now(), jsonb_build_object('pattern', 'a', 'category_id', t.id('cat_keep_ref_rule'))),
    t.up('category_rules', t.id('rule_purge'), 0, now(), jsonb_build_object('pattern', 'b', 'category_id', t.id('cat_live'))),
    t.up('category_rules', t.id('rule_keep_recent'), 0, now(), jsonb_build_object('pattern', 'c', 'category_id', t.id('cat_live'))),
    t.up('recurring_rules', t.id('recur_live'), 0, now(), jsonb_build_object(
      'template', jsonb_build_object('type', 'expense', 'amount', 1, 'account_id', t.id('acc_keep_template'), 'category_id', t.id('cat_keep_template')),
      'frequency', 'monthly', 'next_run_on', '2026-12-01')),
    t.up('recurring_rules', t.id('recur_purge'), 0, now(), '{"template": {}, "frequency": "weekly", "next_run_on": "2026-12-01"}'),
    t.up('recurring_rules', t.id('recur_keep_recent'), 0, now(), '{"template": {}, "frequency": "yearly", "next_run_on": "2026-12-01"}'),
    t.up('monthly_summaries', t.id('sum_live'), 0, now(), '{"month": "2026-10", "stats": {}}'),
    t.up('monthly_summaries', t.id('sum_purge'), 0, now(), '{"month": "2026-07", "stats": {}}'),
    t.up('monthly_summaries', t.id('sum_keep_recent'), 0, now(), '{"month": "2026-09", "stats": {}}')));
  assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e),
    format('준비 push 실패: %s', (select jsonb_agg(e) from jsonb_array_elements(r -> 'results') e where e ->> 'status' <> 'applied'));

  -- 삭제 표시를 만든다(push로). 이름에 purge · keep이 든 행 가운데 "live"가 아닌 것 전부.
  r := t.push(l, (
    select jsonb_agg(t.del(x.tbl, t.id(x.k), 1, now()))
      from (values
        ('accounts', 'acc_purge_free'), ('accounts', 'acc_keep_recent'), ('accounts', 'acc_keep_ref_live_tx'),
        ('accounts', 'acc_keep_ref_to_account'), ('accounts', 'acc_keep_ref_recent_tomb_tx'),
        ('accounts', 'acc_purge_ref_old_tomb_tx'), ('accounts', 'acc_keep_payment'), ('accounts', 'acc_keep_default'),
        ('accounts', 'acc_keep_template'),
        ('categories', 'cat_purge_free'), ('categories', 'cat_keep_recent'), ('categories', 'cat_keep_ref_tx'),
        ('categories', 'cat_keep_ref_budget'), ('categories', 'cat_keep_ref_rule'), ('categories', 'cat_purge_parent'),
        ('categories', 'cat_purge_child'), ('categories', 'cat_keep_parent'), ('categories', 'cat_keep_template'),
        ('transactions', 'tx_purge_old'), ('transactions', 'tx_keep_recent'), ('transactions', 'tx_purge_old_ref'),
        ('budgets', 'budget_purge'), ('budgets', 'budget_keep_recent'),
        ('category_rules', 'rule_purge'), ('category_rules', 'rule_keep_recent'),
        ('recurring_rules', 'recur_purge'), ('recurring_rules', 'recur_keep_recent'),
        ('monthly_summaries', 'sum_purge'), ('monthly_summaries', 'sum_keep_recent')) as x (tbl, k)));
  assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e), format('%s', r);
  perform t.logout();

  -- "최근"이 아닌 삭제 표시를 100일 전으로 돌린다(시험 준비라서 직접 고친다).
  select array_agg(t.id(o.name)) into old_ids from unnest(array[
    'acc_purge_free', 'acc_keep_ref_live_tx', 'acc_keep_ref_to_account', 'acc_keep_ref_recent_tomb_tx',
    'acc_purge_ref_old_tomb_tx', 'acc_keep_payment', 'acc_keep_default', 'acc_keep_template',
    'cat_purge_free', 'cat_keep_ref_tx', 'cat_keep_ref_budget', 'cat_keep_ref_rule', 'cat_purge_parent',
    'cat_purge_child', 'cat_keep_parent', 'cat_keep_template',
    'tx_purge_old', 'tx_purge_old_ref', 'budget_purge', 'rule_purge', 'recur_purge', 'sum_purge']) as o (name);
  update public.accounts          set deleted_at = now() - interval '100 days' where id = any (old_ids);
  update public.categories        set deleted_at = now() - interval '100 days' where id = any (old_ids);
  update public.transactions      set deleted_at = now() - interval '100 days' where id = any (old_ids);
  update public.budgets           set deleted_at = now() - interval '100 days' where id = any (old_ids);
  update public.category_rules    set deleted_at = now() - interval '100 days' where id = any (old_ids);
  update public.recurring_rules   set deleted_at = now() - interval '100 days' where id = any (old_ids);
  update public.monthly_summaries set deleted_at = now() - interval '100 days' where id = any (old_ids);

  -- push 결과 기록: 하나는 100일 전 것으로 만든다.
  assert (select count(*) from public.sync_batches where ledger_id = l) = 2;
  update public.sync_batches set created_at = now() - interval '100 days'
   where ledger_id = l and batch_id = (select batch_id from public.sync_batches where ledger_id = l order by created_at, batch_id limit 1);
end $$;

-- 행이 있는지 본다(이름으로).
create or replace function t.has(p_table text, p_key text) returns boolean
language plpgsql as $$
declare
  v boolean;
begin
  execute format('select exists (select 1 from public.%I where id = $1)', p_table) into v using t.id(p_key);
  return v;
end $$;

-- 서비스 역할이 정리를 돌린다.
do $$
declare
  l   uuid := t.id('lp');
  out jsonb;
  k   text;
begin
  -- 사용자는 못 부른다.
  perform t.login(t.id('p'));
  assert t.sqlstate_of('select public.purge_tombstones()') = '42501', 'authenticated는 정리를 못 돌린다';
  perform t.logout();

  perform set_config('role', 'service_role', true);
  assert current_user = 'service_role';
  -- 인자 확인
  assert t.sqlstate_of('select public.purge_tombstones(null)') = '22023', 'null 기간';
  assert t.sqlstate_of($q$select public.purge_tombstones(interval '-1 day')$q$) = '22023', '음수 기간';
  out := public.purge_tombstones();
  perform set_config('role', 'none', true);

  -- 지운 수(다른 시험의 삭제 표시는 모두 최근 것이라 여기에 끼지 않는다)
  assert out = '{"transactions": 2, "budgets": 1, "category_rules": 1, "recurring_rules": 1, "monthly_summaries": 1,
                 "categories": 3, "accounts": 2, "sync_batches": 1}'::jsonb, format('지운 수: %s', out);

  -- 지워져야 하는 것
  assert not t.has('transactions', 'tx_purge_old') and not t.has('transactions', 'tx_purge_old_ref'), '오래된 거래 삭제 표시';
  assert not t.has('budgets', 'budget_purge') and not t.has('category_rules', 'rule_purge')
     and not t.has('recurring_rules', 'recur_purge') and not t.has('monthly_summaries', 'sum_purge'), '그 밖의 오래된 삭제 표시';
  assert not t.has('categories', 'cat_purge_free'), '아무도 가리키지 않는 분류';
  assert not t.has('categories', 'cat_purge_child') and not t.has('categories', 'cat_purge_parent'),
    '지운 소분류와 그 대분류는 한 번에 지워진다';
  assert not t.has('accounts', 'acc_purge_free'), '아무도 가리키지 않는 자산';
  assert not t.has('accounts', 'acc_purge_ref_old_tomb_tx'), '오래전에 지운 거래만 가리키던 자산(거래가 먼저 지워진다)';

  -- 남아야 하는 것: 최근 삭제 표시
  foreach k in array array['acc_keep_recent'] loop
    assert t.has('accounts', k), format('%s가 지워졌다', k);
  end loop;
  assert t.has('categories', 'cat_keep_recent') and t.has('transactions', 'tx_keep_recent')
     and t.has('budgets', 'budget_keep_recent') and t.has('category_rules', 'rule_keep_recent')
     and t.has('recurring_rules', 'recur_keep_recent') and t.has('monthly_summaries', 'sum_keep_recent'),
    '최근 삭제 표시는 남는다';
  -- 남아야 하는 것: 남은 행이 가리키는 오래된 삭제 표시
  foreach k in array array['acc_keep_ref_live_tx', 'acc_keep_ref_to_account', 'acc_keep_ref_recent_tomb_tx',
                           'acc_keep_payment', 'acc_keep_default', 'acc_keep_template'] loop
    assert t.has('accounts', k), format('%s가 지워졌다(남은 행이 가리킨다)', k);
  end loop;
  foreach k in array array['cat_keep_ref_tx', 'cat_keep_ref_budget', 'cat_keep_ref_rule', 'cat_keep_parent', 'cat_keep_template'] loop
    assert t.has('categories', k), format('%s가 지워졌다(남은 행이 가리킨다)', k);
  end loop;
  -- 살아 있는 행은 물론 그대로다.
  assert t.has('accounts', 'acc_live') and t.has('accounts', 'acc_live_card') and t.has('categories', 'cat_live')
     and t.has('categories', 'cat_live_child') and t.has('transactions', 'tx_live') and t.has('transactions', 'tx_live_transfer')
     and t.has('budgets', 'budget_live') and t.has('category_rules', 'rule_live') and t.has('recurring_rules', 'recur_live')
     and t.has('monthly_summaries', 'sum_live'), '살아 있는 행이 지워졌다';
  assert (select count(*) from public.categories where ledger_id = l and deleted_at is null) = 16 + 2, '시드 분류와 살아 있는 분류';
  assert (select count(*) from public.sync_batches where ledger_id = l) = 1, '오래된 push 결과만 지워진다';

  -- 다시 돌려도 더 지울 것이 없다.
  perform set_config('role', 'service_role', true);
  out := public.purge_tombstones();
  perform set_config('role', 'none', true);
  assert (select bool_and(v::bigint = 0) from jsonb_each_text(out) as e (k2, v)), format('두 번째 정리: %s', out);
end $$;

-- 참조가 풀리면 다음 정리 때 지워진다. 기간도 바꿀 수 있다.
do $$
declare
  p   uuid := t.id('p');
  l   uuid := t.id('lp');
  out jsonb;
  r   jsonb;
begin
  -- 살아 있던 거래 · 예산 · 규칙 · 반복 거래 · 카드 · 소분류를 지우고, 프로필의 기본 자산을 바꾼다.
  perform t.login(p);
  r := t.push(l, jsonb_build_array(
    t.del('transactions', t.id('tx_live'), 1, now()),
    t.del('transactions', t.id('tx_live_transfer'), 1, now()),
    t.del('budgets', t.id('budget_live'), 1, now()),
    t.del('category_rules', t.id('rule_live'), 1, now()),
    t.del('recurring_rules', t.id('recur_live'), 1, now()),
    t.del('accounts', t.id('acc_live_card'), 1, now()),
    t.del('categories', t.id('cat_live_child'), 1, now()),
    t.up('profiles', p, 2, now(), jsonb_build_object('default_account_id', t.id('acc_live')))));
  assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e), format('%s', r);
  perform t.logout();

  -- 방금 지운 것들은 60일 전에 지운 것으로 돌린다. 기본 기간(90일)으로는 아직 지워지지 않고,
  -- 그것들이 가리키는 100일 된 삭제 표시도 붙잡혀 있다.
  update public.transactions    set deleted_at = now() - interval '60 days' where id in (t.id('tx_live'), t.id('tx_live_transfer'));
  update public.budgets         set deleted_at = now() - interval '60 days' where id = t.id('budget_live');
  update public.category_rules  set deleted_at = now() - interval '60 days' where id = t.id('rule_live');
  update public.recurring_rules set deleted_at = now() - interval '60 days' where id = t.id('recur_live');
  update public.accounts        set deleted_at = now() - interval '60 days' where id = t.id('acc_live_card');
  update public.categories      set deleted_at = now() - interval '60 days' where id = t.id('cat_live_child');

  -- 다만 프로필이 더는 가리키지 않게 된 100일 된 자산 하나는 바로 풀린다.
  perform set_config('role', 'service_role', true);
  out := public.purge_tombstones();
  assert out = '{"transactions": 0, "budgets": 0, "category_rules": 0, "recurring_rules": 0, "monthly_summaries": 0,
                 "categories": 0, "accounts": 1, "sync_batches": 0}'::jsonb, format('90일 기준으로 지운 수: %s', out);
  assert not t.has('accounts', 'acc_keep_default'), '프로필이 가리키지 않게 된 자산은 지워진다';
  assert t.has('transactions', 'tx_live') and t.has('accounts', 'acc_keep_ref_live_tx')
     and t.has('accounts', 'acc_keep_payment') and t.has('categories', 'cat_keep_parent'),
    '60일 된 삭제 표시와, 그것이 가리키는 행은 아직 남는다';

  -- 30일 기준으로 돌리면 60일 된 삭제 표시가 지워지고, 그것들이 붙잡고 있던 오래된 자산 · 분류도 풀린다.
  out := public.purge_tombstones(interval '30 days');
  perform set_config('role', 'none', true);
  assert out = '{"transactions": 2, "budgets": 1, "category_rules": 1, "recurring_rules": 1, "monthly_summaries": 0,
                 "categories": 6, "accounts": 5, "sync_batches": 0}'::jsonb, format('30일 기준으로 지운 수: %s', out);
  assert not t.has('accounts', 'acc_keep_ref_live_tx') and not t.has('accounts', 'acc_keep_ref_to_account')
     and not t.has('accounts', 'acc_keep_payment') and not t.has('accounts', 'acc_keep_template')
     and not t.has('accounts', 'acc_live_card'), '풀린 자산이 지워진다(카드와 그 결제 계좌는 한 번에)';
  assert not t.has('categories', 'cat_keep_ref_tx') and not t.has('categories', 'cat_keep_ref_budget')
     and not t.has('categories', 'cat_keep_ref_rule') and not t.has('categories', 'cat_keep_parent')
     and not t.has('categories', 'cat_keep_template') and not t.has('categories', 'cat_live_child'), '풀린 분류가 지워진다';
  -- 최근에 지운 거래가 가리키는 자산은 아직 남는다. 살아 있는 것도 그대로다.
  assert t.has('accounts', 'acc_keep_ref_recent_tomb_tx') and t.has('transactions', 'tx_keep_recent');
  assert t.has('accounts', 'acc_live') and t.has('categories', 'cat_live') and t.has('accounts', 'acc_keep_recent');
end $$;

-- 정리가 모르는 FK가 삭제를 막아도(나중에 참조 테이블이 늘거나, 확인과 삭제 사이에 push가 끼어든 경우)
-- 정리는 실패하지 않고 그 테이블만 이번에 건너뛴다.
drop table if exists t.extra_ref;
create table t.extra_ref (account_id uuid references public.accounts (id));

do $$
declare
  p    uuid := t.id('p');
  l    uuid := t.id('lp');
  acc  uuid := gen_random_uuid();
  acc2 uuid := gen_random_uuid();
  tx   uuid := gen_random_uuid();
  out  jsonb;
begin
  perform t.login(p);
  perform t.push1(l, t.up('accounts', acc, 0, now(), t.acc('정리가 모르는 표가 가리킴')));
  perform t.push1(l, t.del('accounts', acc, 1, now()));
  perform t.push1(l, t.up('accounts', acc2, 0, now(), t.acc('아무도 안 가리킴')));
  perform t.push1(l, t.del('accounts', acc2, 1, now()));
  perform t.push1(l, t.up('transactions', tx, 0, now(), t.tx(t.id('acc_live'))));
  perform t.push1(l, t.del('transactions', tx, 1, now()));
  perform t.logout();
  update public.accounts set deleted_at = now() - interval '100 days' where id in (acc, acc2);
  update public.transactions set deleted_at = now() - interval '100 days' where id = tx;
  insert into t.extra_ref values (acc);

  perform set_config('role', 'service_role', true);
  out := public.purge_tombstones();
  perform set_config('role', 'none', true);
  assert (out ->> 'accounts')::int = 0 and (out ->> 'transactions')::int = 1, format('건너뛴 정리: %s', out);
  assert (select count(*) from public.accounts where id in (acc, acc2)) = 2, '막힌 테이블은 이번에 건드리지 않는다';

  -- 막던 참조가 사라지면 다음 정리에서 지워진다.
  delete from t.extra_ref;
  perform set_config('role', 'service_role', true);
  out := public.purge_tombstones();
  perform set_config('role', 'none', true);
  assert (out ->> 'accounts')::int = 2, format('다음 정리: %s', out);
end $$;

drop table t.extra_ref;
