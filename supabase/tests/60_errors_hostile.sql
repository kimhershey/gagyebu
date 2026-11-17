-- 60_errors_hostile.sql
-- 한 건의 실패가 묶음을 깨지 않는다. 그리고 악의적인 기기가 보낼 만한 입력을 하나씩 넣어 본다.
\ir _helpers.sql

-- ---------------------------------------------------------------------------
-- 준비: 피해자 A(자산 · 분류 · 거래가 있다)와 공격자 B
-- ---------------------------------------------------------------------------
do $$
declare
  a uuid := t.signup();
  b uuid := t.signup();
  k text;
  r jsonb;
begin
  perform t.set('a', a::text);
  perform t.set('la', t.ledger_of(a)::text);
  perform t.set('b', b::text);
  perform t.set('lb', t.ledger_of(b)::text);
  foreach k in array array['acc_a', 'cat_a', 'tx_a', 'acc_b', 'cat_b'] loop
    perform t.set(k, gen_random_uuid()::text);
  end loop;

  perform t.login(a);
  r := t.push(t.id('la'), jsonb_build_array(
    t.up('accounts', t.id('acc_a'), 0, now(), '{"name": "A의 비밀통장", "kind": "bank", "opening_balance": 777}'),
    t.up('categories', t.id('cat_a'), 0, now(), '{"name": "A의 분류", "kind": "expense"}'),
    t.up('transactions', t.id('tx_a'), 0, now(), t.tx(t.id('acc_a'), 'SECRET-MEMO'))));
  assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e), format('%s', r);
  perform t.logout();

  perform t.login(b);
  r := t.push(t.id('lb'), jsonb_build_array(
    t.up('accounts', t.id('acc_b'), 0, now(), t.acc('B의 통장')),
    t.up('categories', t.id('cat_b'), 0, now(), '{"name": "B의 분류", "kind": "expense"}')));
  assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e), format('%s', r);
  perform t.logout();

  -- 공격 뒤에 견줄 A의 원래 행들
  perform t.set('snap_tx_a', t.row_of('transactions', t.id('tx_a'))::text);
  perform t.set('snap_acc_a', t.row_of('accounts', t.id('acc_a'))::text);
  perform t.set('snap_ledger_a', t.row_of('ledgers', t.id('la'))::text);
  perform t.set('snap_profile_a', t.row_of('profiles', a)::text);
end $$;

-- ---------------------------------------------------------------------------
-- 제약을 어긴 한 건만 error이고 나머지는 적용된다.
-- ---------------------------------------------------------------------------
do $$
declare
  b    uuid := t.id('b');
  lb   uuid := t.id('lb');
  ok1  uuid := gen_random_uuid();
  ok2  uuid := gen_random_uuid();
  ok3  uuid := gen_random_uuid();
  bad  uuid[] := array[gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
                       gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];
  r    jsonb;
  x    jsonb;
  i    integer;
begin
  perform t.login(b);
  r := t.push(lb, jsonb_build_array(
    /* 0 */ t.up('transactions', ok1, 0, now(), t.tx(t.id('acc_b'), '정상 1')),
    /* 1 check: 이체인데 받는 자산이 없다 */
            t.up('transactions', bad[1], 0, now(), t.tx(t.id('acc_b'), 'SECRET-IN-BAD-ROW') || '{"type": "transfer"}'),
    /* 2 */ t.up('transactions', ok2, 0, now(), t.tx(t.id('acc_b'), '정상 2')),
    /* 3 check: 열거형 밖의 값 */
            t.up('transactions', bad[2], 0, now(), t.tx(t.id('acc_b')) || '{"source": "telepathy"}'),
    /* 4 not null: 금액이 없다 */
            t.up('transactions', bad[3], 0, now(), t.tx(t.id('acc_b')) - 'amount'),
    /* 5 check: 예산 월의 꼴 */
            t.up('budgets', bad[4], 0, now(), '{"month": "2026-13", "amount": 1}'),
    /* 6 check: 음수 예산 */
            t.up('budgets', bad[5], 0, now(), '{"month": "2026-11", "amount": -1}'),
    /* 7 타입: 숫자 자리에 글자 */
            t.up('transactions', bad[6], 0, now(), t.tx(t.id('acc_b')) || '{"amount": "천원"}'),
    /* 8 타입: 날짜가 아니다 */
            t.up('transactions', bad[7], 0, now(), t.tx(t.id('acc_b')) || '{"occurred_on": "어제"}'),
    /* 9 */ t.up('accounts', ok3, 0, now(), t.acc('정상 3'))));

  assert jsonb_array_length(r -> 'results') = 10;
  foreach i in array array[0, 2, 9] loop
    x := r -> 'results' -> i;
    assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 1, format('정상 변경 %s는 적용돼야 한다: %s', i, x);
  end loop;
  foreach i in array array[1, 3, 4, 5, 6, 7, 8] loop
    x := r -> 'results' -> i;
    assert x ->> 'status' = 'error', format('변경 %s는 error여야 한다: %s', i, x);
    assert x ->> 'error' is not null and length(x ->> 'error') > 0, 'error에는 메시지가 있다';
    assert x -> 'version' = 'null' and x -> 'server_seq' = 'null' and x -> 'server_row' = 'null',
      format('error에는 version · server_seq · server_row가 없다: %s', x);
  end loop;
  assert r -> 'results' -> 1 ->> 'error' ~ 'check constraint', format('check 위반 메시지: %s', r -> 'results' -> 1 ->> 'error');
  assert r -> 'results' -> 4 ->> 'error' ~ 'not-null', format('not null 위반 메시지: %s', r -> 'results' -> 4 ->> 'error');
  -- 메시지에 행의 내용(DETAIL의 "Failing row contains …")이 실려 나가지 않는다.
  assert r::text !~ 'SECRET-IN-BAD-ROW', '오류 메시지에 행의 내용이 들어가면 안 된다';

  -- 실패한 행은 없고 성공한 행만 있다.
  assert t.row_of('transactions', ok1) is not null and t.row_of('transactions', ok2) is not null
     and t.row_of('accounts', ok3) is not null, '정상 행 3개가 있어야 한다';
  assert (select count(*) from public.transactions where id = any (bad)) = 0
     and (select count(*) from public.budgets where id = any (bad)) = 0, '실패한 행은 남지 않는다';
  assert (r ->> 'max_server_seq')::bigint = (r -> 'results' -> 2 ->> 'server_seq')::bigint,
    'max_server_seq는 적용된 것 가운데 가장 큰 번호(거래가 자산보다 뒤에 적용된다)';

  -- 있던 행을 고치다 실패해도 그 행은 그대로다.
  x := t.push1(lb, t.up('transactions', ok1, 1, now(), '{"type": "transfer"}'));
  assert x ->> 'status' = 'error', format('%s', x);
  x := t.row_of('transactions', ok1);
  assert x ->> 'type' = 'expense' and (x ->> 'version')::int = 1, '실패한 수정은 흔적을 남기지 않는다';
end $$;

-- ---------------------------------------------------------------------------
-- 다른 가계부의 행 ID를 건드리면 error다. 그 행을 보여 주지도 바꾸지도 않는다.
-- ---------------------------------------------------------------------------
do $$
declare
  b  uuid := t.id('b');
  lb uuid := t.id('lb');
  r  jsonb;
  x  jsonb;
begin
  perform t.login(b);
  r := t.push(lb, jsonb_build_array(
    /* 0 새 행인 척 */        t.up('transactions', t.id('tx_a'), 0, now(), t.tx(t.id('acc_b'), 'B가 덮어씀')),
    /* 1 버전을 맞춰서 */     t.up('transactions', t.id('tx_a'), 1, now(), '{"memo": "B가 덮어씀"}'),
    /* 2 낡은 버전 + 미래 */  t.up('transactions', t.id('tx_a'), 0, now() + interval '1 day', '{"memo": "B가 덮어씀"}'),
    /* 3 지우기 */            t.del('transactions', t.id('tx_a'), 1, now()),
    /* 4 낡은 버전으로 지우기 */ t.del('accounts', t.id('acc_a'), 0, now()),
    /* 5 자산 가로채기 */     t.up('accounts', t.id('acc_a'), 1, now(), t.acc('B가 가져감')),
    /* 6 */                   t.del('categories', t.id('cat_a'), 1, now())));
  for x in select e from jsonb_array_elements(r -> 'results') e loop
    assert x ->> 'status' = 'error', format('남의 행 ID는 error여야 한다: %s', x);
    assert x -> 'server_row' = 'null' and x -> 'version' = 'null' and x -> 'server_seq' = 'null',
      format('남의 행을 돌려주면 안 된다: %s', x);
  end loop;
  -- 결과 어디에도 A의 내용이 없다.
  assert r::text !~ 'SECRET-MEMO' and r::text !~ '비밀통장' and r::text !~ t.get('la'),
    format('결과에 남의 행 내용이 새어 나갔다: %s', r);
  assert r -> 'max_server_seq' = 'null', '아무것도 쓰지 않았다';

  -- B의 가계부에도 그 ID의 행이 생기지 않았다.
  assert t.row_of('transactions', t.id('tx_a')) is null and t.row_of('accounts', t.id('acc_a')) is null,
    'B의 눈에는 여전히 없는 행이다';

  -- A의 행은 그대로다.
  perform t.logout();
  assert t.row_of('transactions', t.id('tx_a')) = t.get('snap_tx_a')::jsonb, 'A의 거래가 바뀌었다';
  assert t.row_of('accounts', t.id('acc_a')) = t.get('snap_acc_a')::jsonb, 'A의 자산이 바뀌었다';
  assert (select count(*) from public.categories where id = t.id('cat_a') and deleted_at is null) = 1, 'A의 분류가 지워졌다';
end $$;

-- ---------------------------------------------------------------------------
-- 다른 가계부의 행을 "가리키는" 것도 안 된다. 없는 ID를 가리킬 때와 답이 똑같아야 한다
-- (그 ID가 다른 가계부에 있는지 알려 주지 않는다).
-- 막지 않으면 B의 거래가 A의 자산을 붙잡아, A가 계정을 지울 수 없게 된다.
-- ---------------------------------------------------------------------------
do $$
declare
  b    uuid := t.id('b');
  lb   uuid := t.id('lb');
  none uuid := gen_random_uuid();
  r    jsonb;
  i    integer;
begin
  perform t.login(b);
  r := t.push(lb, jsonb_build_array(
    /* 0 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_a'))),
    /* 1 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(none)),
    /* 2 */ t.up('transactions', gen_random_uuid(), 0, now(),
                 t.tx(t.id('acc_b')) || jsonb_build_object('type', 'transfer', 'to_account_id', t.id('acc_a'))),
    /* 3 */ t.up('transactions', gen_random_uuid(), 0, now(),
                 t.tx(t.id('acc_b')) || jsonb_build_object('type', 'transfer', 'to_account_id', none)),
    /* 4 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || jsonb_build_object('category_id', t.id('cat_a'))),
    /* 5 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || jsonb_build_object('category_id', none)),
    /* 6 */ t.up('budgets', gen_random_uuid(), 0, now(), jsonb_build_object('month', '2026-11', 'amount', 1, 'category_id', t.id('cat_a'))),
    /* 7 */ t.up('budgets', gen_random_uuid(), 0, now(), jsonb_build_object('month', '2026-11', 'amount', 1, 'category_id', none)),
    /* 8 */ t.up('category_rules', gen_random_uuid(), 0, now(), jsonb_build_object('pattern', 'x', 'category_id', t.id('cat_a'))),
    /* 9 */ t.up('category_rules', gen_random_uuid(), 0, now(), jsonb_build_object('pattern', 'x', 'category_id', none))));
  for i in 0..9 loop
    assert r -> 'results' -> i ->> 'status' = 'error', format('남의 행을 가리키는 변경 %s: %s', i, r -> 'results' -> i);
  end loop;
  foreach i in array array[0, 2, 4, 6, 8] loop
    assert r -> 'results' -> i ->> 'error' = r -> 'results' -> (i + 1) ->> 'error',
      format('남의 행과 없는 행의 오류가 달라 구별된다: %s / %s', r -> 'results' -> i ->> 'error', r -> 'results' -> (i + 1) ->> 'error');
  end loop;

  -- 있던 행을 고쳐서 남의 행을 가리키게 하는 것도 안 된다.
  perform t.set('tx_b', gen_random_uuid()::text);
  assert t.push1(lb, t.up('transactions', t.id('tx_b'), 0, now(), t.tx(t.id('acc_b')))) ->> 'status' = 'applied';
  assert t.push1(lb, t.up('transactions', t.id('tx_b'), 1, now(), jsonb_build_object('account_id', t.id('acc_a')))) ->> 'status' = 'error';
  assert t.push1(lb, t.up('transactions', t.id('tx_b'), 1, now(), jsonb_build_object('category_id', t.id('cat_a')))) ->> 'status' = 'error';
  assert t.row_of('transactions', t.id('tx_b')) ->> 'account_id' = t.get('acc_b'), 'B의 거래는 여전히 B의 자산을 가리킨다';

  -- 자기 가계부의 행은 가리킬 수 있다(삭제 표시가 있어도).
  assert t.push1(lb, t.up('transactions', t.id('tx_b'), 1, now(), jsonb_build_object('category_id', t.id('cat_b')))) ->> 'status' = 'applied';

  perform t.logout();
  assert (select count(*) from public.transactions x
           where x.ledger_id = lb and (x.account_id = t.id('acc_a') or x.to_account_id = t.id('acc_a')
                                       or x.category_id = t.id('cat_a'))) = 0, '가계부를 넘나드는 참조가 생겼다';
  assert (select count(*) from public.budgets where category_id = t.id('cat_a')) = 0
     and (select count(*) from public.category_rules where category_id = t.id('cat_a')) = 0;
end $$;

-- ---------------------------------------------------------------------------
-- table에 SQL을 넣어 본다. 허용 목록에 없는 이름은 모두 error이고 아무 일도 일어나지 않는다.
-- ---------------------------------------------------------------------------
do $$
declare
  b    uuid := t.id('b');
  lb   uuid := t.id('lb');
  name text;
  x    jsonb;
  n0   bigint;
  seq0 bigint := t.seq();
begin
  select count(*) into n0 from public.sync_batches;
  perform t.login(b);
  foreach name in array array[
    'transactions; drop table public.ledgers; --',
    'accounts" as t where true; delete from public.ledgers; --',
    'accounts'' or ''1''=''1',
    'sync_batches', 'server_seq', 'pg_catalog.pg_class', 'pg_class', 'auth.users', 'users',
    'public.accounts', '"accounts"', 'Accounts', 'ACCOUNTS', ' accounts', 'accounts ', '', '%I', '$1'] loop
    x := t.push1(lb, jsonb_build_object('table', name, 'op', 'upsert', 'id', gen_random_uuid(),
                                        'base_version', 0, 'client_updated_at', now(), 'data', t.acc('주입')));
    assert x ->> 'status' = 'error' and x ->> 'table' = name, format('table %L: %s', name, x);
    x := t.push1(lb, jsonb_build_object('table', name, 'op', 'delete', 'id', t.id('acc_b'),
                                        'base_version', 1, 'client_updated_at', now()));
    assert x ->> 'status' = 'error', format('table %L (delete): %s', name, x);
  end loop;
  -- 문자열이 아닌 table
  assert t.push1(lb, jsonb_build_object('table', 42, 'op', 'delete', 'id', gen_random_uuid(), 'base_version', 0, 'client_updated_at', now())) ->> 'status' = 'error';
  assert t.push1(lb, jsonb_build_object('table', null, 'op', 'delete', 'id', gen_random_uuid(), 'base_version', 0, 'client_updated_at', now())) ->> 'status' = 'error';
  assert t.push1(lb, jsonb_build_object('table', jsonb_build_array('accounts'), 'op', 'delete', 'id', gen_random_uuid(), 'base_version', 0, 'client_updated_at', now())) ->> 'status' = 'error';

  -- data의 키에 SQL을 넣어도 모르는 키라 무시된다.
  x := t.push1(lb, t.up('accounts', gen_random_uuid(), 0, now(),
         t.acc('키 주입') || '{"name\"; drop table public.ledgers; --": 1, "kind = ''cash'' --": 2}'));
  assert x ->> 'status' = 'applied', format('모르는 키는 무시한다: %s', x);

  perform t.logout();
  assert to_regclass('public.ledgers') is not null and to_regclass('public.accounts') is not null, '테이블이 사라졌다';
  assert (select count(*) from public.ledgers where id in (t.id('la'), t.id('lb'))) = 2, '가계부가 지워졌다';
  assert (select count(*) from public.accounts where id = t.id('acc_b') and deleted_at is null and version = 1) = 1,
    'B의 자산이 바뀌었다';
  assert t.seq() = seq0 + 1, '적용된 한 건만 번호를 썼다';
end $$;

-- ---------------------------------------------------------------------------
-- 서버가 관리하는 컬럼은 data에 넣어도 무시한다(id, ledger_id, version, server_seq, 시각들, 생성 컬럼, owner_id).
-- ---------------------------------------------------------------------------
do $$
declare
  a    uuid := t.id('a');
  b    uuid := t.id('b');
  la   uuid := t.id('la');
  lb   uuid := t.id('lb');
  acc  uuid := gen_random_uuid();
  tx   uuid := gen_random_uuid();
  old  timestamptz := '2000-01-01T00:00:00Z';
  r    jsonb;
  x    jsonb;
begin
  perform t.login(b);
  r := t.push(lb, jsonb_build_array(
    t.up('accounts', acc, 0, now() - interval '1 hour', t.acc('덮어쓰기 시도') || jsonb_build_object(
      'id', gen_random_uuid(), 'ledger_id', la, 'version', 999, 'server_seq', 1,
      'created_at', old, 'updated_at', old, 'deleted_at', old, 'client_updated_at', old)),
    t.up('transactions', tx, 0, now() - interval '1 hour', t.tx(acc) || jsonb_build_object(
      'receiver', '진짜 상대', 'counterparty', '가짜 상대', 'ledger_id', la, 'version', -5, 'server_seq', -1)),
    t.up('ledgers', lb, 1, now() - interval '1 hour', jsonb_build_object(
      'name', 'B의 가계부', 'owner_id', a, 'id', la, 'version', 50, 'server_seq', 2, 'deleted_at', now())),
    t.up('profiles', b, 1, now() - interval '1 hour', jsonb_build_object(
      'display_name', 'B', 'id', a, 'ledger_id', la, 'version', 50, 'deleted_at', now()))));
  assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e), format('%s', r);
  assert (r -> 'results' -> 0 ->> 'version')::int = 1 and (r -> 'results' -> 2 ->> 'version')::int = 2;

  x := t.row_of('accounts', acc);
  assert x ->> 'id' = acc::text and x ->> 'ledger_id' = lb::text, format('id · ledger_id는 서버가 정한다: %s', x);
  assert (x ->> 'version')::int = 1 and (x ->> 'server_seq')::bigint = (r -> 'results' -> 0 ->> 'server_seq')::bigint,
    format('version · server_seq는 서버가 정한다: %s', x);
  assert (x ->> 'created_at')::timestamptz = now() and (x ->> 'updated_at')::timestamptz = now()
     and x -> 'deleted_at' = 'null', format('created_at · updated_at · deleted_at은 서버가 정한다: %s', x);
  assert (x ->> 'client_updated_at')::timestamptz = now() - interval '1 hour',
    'client_updated_at은 data가 아니라 변경의 값이다';

  x := t.row_of('transactions', tx);
  assert x ->> 'counterparty' = '진짜 상대' and x ->> 'ledger_id' = lb::text and (x ->> 'version')::int = 1,
    format('생성 컬럼은 쓸 수 없다: %s', x);

  x := t.row_of('ledgers', lb);
  assert x ->> 'owner_id' = b::text and x ->> 'id' = lb::text and (x ->> 'version')::int = 2
     and x -> 'deleted_at' = 'null' and x ->> 'name' = 'B의 가계부', format('ledgers는 name · currency만 바뀐다: %s', x);

  x := t.row_of('profiles', b);
  assert x ->> 'id' = b::text and x ->> 'ledger_id' = lb::text and (x ->> 'version')::int = 2
     and x -> 'deleted_at' = 'null' and x ->> 'display_name' = 'B', format('profiles: %s', x);

  perform t.logout();
  assert (select count(*) from public.accounts where ledger_id = la and name = '덮어쓰기 시도') = 0, 'A의 가계부에 행이 들어갔다';
  assert t.row_of('ledgers', la) = t.get('snap_ledger_a')::jsonb, 'A의 가계부 행이 바뀌었다';
end $$;

-- ---------------------------------------------------------------------------
-- ledgers는 만들거나 지울 수 없고, profiles는 자기 것만 고칠 수 있고 지울 수 없다.
-- ---------------------------------------------------------------------------
do $$
declare
  a  uuid := t.id('a');
  b  uuid := t.id('b');
  la uuid := t.id('la');
  lb uuid := t.id('lb');
  r  jsonb;
  x  jsonb;
  n  bigint;
begin
  select count(*) into n from public.ledgers;
  perform t.login(b);
  r := t.push(lb, jsonb_build_array(
    /* 0 */ t.up('ledgers', gen_random_uuid(), 0, now(), '{"name": "가계부 하나 더"}'),
    /* 1 */ t.up('ledgers', la, 1, now(), '{"name": "A의 가계부 이름 바꾸기"}'),
    /* 2 */ t.del('ledgers', lb, 2, now()),
    /* 3 */ t.del('ledgers', la, 1, now()),
    /* 4 */ t.up('profiles', a, 1, now(), '{"display_name": "A의 프로필 바꾸기"}'),
    /* 5 */ t.up('profiles', gen_random_uuid(), 0, now(), '{"display_name": "프로필 하나 더"}'),
    /* 6 */ t.del('profiles', b, 2, now()),
    /* 7 */ t.del('profiles', a, 1, now())));
  for x in select e from jsonb_array_elements(r -> 'results') e loop
    assert x ->> 'status' = 'error' and x -> 'server_row' = 'null', format('ledgers · profiles 제한: %s', x);
  end loop;
  -- 남의 가계부 · 프로필이 있든 없든 답이 같다.
  assert r -> 'results' -> 0 ->> 'error' = r -> 'results' -> 1 ->> 'error', '있는 가계부와 없는 가계부의 오류가 같다';
  assert r -> 'results' -> 4 ->> 'error' = r -> 'results' -> 5 ->> 'error', '있는 프로필과 없는 프로필의 오류가 같다';

  perform t.logout();
  assert (select count(*) from public.ledgers) = n, '가계부 수가 바뀌었다';
  assert t.row_of('ledgers', la) = t.get('snap_ledger_a')::jsonb, 'A의 가계부가 바뀌었다';
  assert t.row_of('profiles', a) = t.get('snap_profile_a')::jsonb, 'A의 프로필이 바뀌었다';
  assert (select count(*) from public.ledgers where id = lb and deleted_at is null) = 1, 'B의 가계부가 지워졌다';
  assert (select count(*) from public.profiles where id = b and deleted_at is null) = 1, 'B의 프로필이 지워졌다';
  assert (select count(*) from public.profiles where ledger_id = lb) = 1, 'B의 가계부에 프로필이 더 생겼다';
end $$;

-- ---------------------------------------------------------------------------
-- 꼴이 틀린 변경: 그 건만 error이고, 결과의 자리는 보낸 자리와 같다.
-- ---------------------------------------------------------------------------
do $$
declare
  b   uuid := t.id('b');
  lb  uuid := t.id('lb');
  ok  uuid := gen_random_uuid();
  ch  jsonb;
  r   jsonb;
  i   integer;
  c   jsonb := jsonb_build_object('table', 'accounts', 'op', 'upsert', 'id', gen_random_uuid(),
                                  'base_version', 0, 'client_updated_at', now(), 'data', t.acc('x'));
begin
  ch := jsonb_build_array(
    /*  0 */ '"문자열"'::jsonb,
    /*  1 */ '42'::jsonb,
    /*  2 */ 'null'::jsonb,
    /*  3 */ '[]'::jsonb,
    /*  4 */ '{}'::jsonb,
    /*  5 */ c - 'op',
    /*  6 */ c || '{"op": "truncate"}',
    /*  7 */ c || '{"op": "UPSERT"}',
    /*  8 */ c - 'id',
    /*  9 */ c || '{"id": "zzz"}',
    /* 10 */ c || '{"id": 12345}',
    /* 11 */ c - 'base_version',
    /* 12 */ c || '{"base_version": -1}',
    /* 13 */ c || '{"base_version": 1.5}',
    /* 14 */ c || '{"base_version": "0"}',
    /* 15 */ c || '{"base_version": 99999999999999999999}',
    /* 16 */ c || '{"base_version": null}',
    /* 17 */ c - 'client_updated_at',
    /* 18 */ c || '{"client_updated_at": "그저께쯤"}',
    /* 19 */ c || '{"client_updated_at": "infinity"}',
    /* 20 */ c || '{"client_updated_at": "-infinity"}',
    /* 21 */ c || '{"client_updated_at": "0044-03-15 BC"}',
    /* 22 */ c || '{"client_updated_at": 1731819600}',
    /* 23 */ c - 'data',
    /* 24 */ c || '{"data": [1, 2]}',
    /* 25 */ c || '{"data": "문자열"}',
    /* 26 */ c || '{"data": null}',
    /* 27 */ c || '{"data": {}}',
    /* 28 */ c || '{"data": {"name": "x", "kind": "bank", "opening_balance": 1.5}}',
    /* 29 */ c || '{"data": {"name": "x", "kind": "bank", "match_hints": "배열이 아님"}}',
    /* 30 */ c || '{"data": {"name": "x", "kind": "bank", "billing_day": 40}}',
    /* 31 정상 */ t.up('accounts', ok, 0, now(), t.acc('틀린 것들 사이의 정상 변경')));

  perform t.login(b);
  r := t.push(lb, ch);
  assert jsonb_array_length(r -> 'results') = 32, '결과 수는 변경 수와 같다';
  for i in 0..30 loop
    assert r -> 'results' -> i ->> 'status' = 'error' and r -> 'results' -> i ->> 'error' is not null,
      format('꼴이 틀린 변경 %s는 error여야 한다: %s', i, r -> 'results' -> i);
  end loop;
  assert r -> 'results' -> 31 ->> 'status' = 'applied' and r -> 'results' -> 31 ->> 'id' = ok::text,
    format('정상 변경은 적용된다: %s', r -> 'results' -> 31);
  -- 객체가 아닌 변경은 table · id가 null로 돌아온다.
  for i in 0..3 loop
    assert r -> 'results' -> i -> 'table' = 'null' and r -> 'results' -> i -> 'id' = 'null', format('%s', r -> 'results' -> i);
  end loop;
  assert (r ->> 'max_server_seq')::bigint = (r -> 'results' -> 31 ->> 'server_seq')::bigint;
end $$;

-- ---------------------------------------------------------------------------
-- README의 JSON 표현으로 적을 수 없는 값(infinity, 기원전, 다섯 자리 연도, NaN)은 받지 않는다.
-- 받아 주면 pull이 "infinity", "0044-03-15 BC", "NaN" 같은 문자열을 내보내, 한 기기가 넣은 행 때문에
-- 같은 가계부의 다른 기기가 읽기에 실패한다.
-- ---------------------------------------------------------------------------
do $$
declare
  b   uuid := t.id('b');
  lb  uuid := t.id('lb');
  ok  uuid := gen_random_uuid();
  r   jsonb;
  p   jsonb;
  i   integer;
  rec jsonb := '{"template": {}, "frequency": "monthly", "next_run_on": "2026-12-01"}';
begin
  perform t.login(b);
  r := t.push(lb, jsonb_build_array(
    /*  0 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || '{"occurred_on": "infinity"}'),
    /*  1 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || '{"occurred_on": "-infinity"}'),
    /*  2 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || '{"occurred_on": "0044-03-15 BC"}'),
    /*  3 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || '{"occurred_on": "12026-11-16"}'),
    /*  4 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || '{"canceled_at": "infinity"}'),
    /*  5 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || '{"canceled_at": "0044-03-15T00:00:00Z BC"}'),
    /*  6 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || '{"original_amount": "NaN"}'),
    /*  7 */ t.up('transactions', gen_random_uuid(), 0, now(), t.tx(t.id('acc_b')) || '{"original_amount": "Infinity"}'),
    /*  8 */ t.up('recurring_rules', gen_random_uuid(), 0, now(), rec || '{"next_run_on": "infinity"}'),
    /*  9 */ t.up('recurring_rules', gen_random_uuid(), 0, now(), rec || '{"end_on": "-infinity"}'),
    /* 10 정상: 범위의 끝 값들 */
             t.up('transactions', ok, 0, now(), t.tx(t.id('acc_b')) ||
               '{"occurred_on": "9999-12-31", "canceled_at": "0001-01-01T00:00:00Z", "original_amount": -0.5}')));
  for i in 0..9 loop
    assert r -> 'results' -> i ->> 'status' = 'error' and r -> 'results' -> i ->> 'error' ~ 'out of range',
      format('적을 수 없는 값 %s는 error여야 한다: %s', i, r -> 'results' -> i);
  end loop;
  assert r -> 'results' -> 10 ->> 'status' = 'applied', format('범위 안의 값은 적용된다: %s', r -> 'results' -> 10);

  -- 있던 행을 고칠 때도 마찬가지다.
  assert t.push1(lb, t.up('transactions', ok, 1, now(), '{"occurred_on": "infinity"}')) ->> 'status' = 'error';

  -- pull이 내보내는 날짜 · 시각은 모두 약속한 꼴이다.
  p := t.pull_all(lb);
  assert (select bool_and(e -> 'row' ->> 'occurred_on' ~ '^\d{4}-\d\d-\d\d$')
            from jsonb_array_elements(p -> 'changes') e where e ->> 'table' = 'transactions'),
    'occurred_on은 YYYY-MM-DD여야 한다';
  assert (select bool_and(v.value ~ '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?\+00:00$')
            from jsonb_array_elements(p -> 'changes') e,
                 jsonb_each_text(e -> 'row') v
           where v.key in ('client_updated_at', 'created_at', 'updated_at', 'deleted_at', 'canceled_at')
             and v.value is not null),
    '시각은 모두 UTC ISO 8601이어야 한다';
end $$;

-- ---------------------------------------------------------------------------
-- 인자 자체가 틀리면 묶음 전체가 예외다.
-- ---------------------------------------------------------------------------
do $$
declare
  b  uuid := t.id('b');
  lb uuid := t.id('lb');
  n  bigint;
  q  text := 'select public.sync_push(%L, %L, %L, %L)';
begin
  select count(*) into n from public.sync_batches where ledger_id = lb;
  perform t.login(b);
  assert t.sqlstate_of(format(q, lb, t.dev(1), gen_random_uuid(), null)) = '22023', 'p_changes null';
  assert t.sqlstate_of(format(q, lb, t.dev(1), gen_random_uuid(), 'null')) = '22023', 'p_changes JSON null';
  assert t.sqlstate_of(format(q, lb, t.dev(1), gen_random_uuid(), '{"table": "accounts"}')) = '22023', 'p_changes 객체';
  assert t.sqlstate_of(format(q, lb, t.dev(1), gen_random_uuid(), '"x"')) = '22023', 'p_changes 문자열';
  assert t.sqlstate_of(format(q, lb, t.dev(1), gen_random_uuid(), '5')) = '22023', 'p_changes 숫자';
  assert t.sqlstate_of(format(q, lb, null, gen_random_uuid(), '[]')) = '22004', 'p_device_id null';
  assert t.sqlstate_of(format(q, lb, t.dev(1), null, '[]')) = '22004', 'p_batch_id null';
  assert t.sqlstate_of(format(q, null, t.dev(1), gen_random_uuid(), '[]')) = '42501', 'p_ledger_id null';
  assert t.sqlstate_of(format(q, lb, t.dev(1), gen_random_uuid(), '[]')) = '00000', '빈 배열은 된다';
  perform t.logout();
  assert (select count(*) from public.sync_batches where ledger_id = lb) = n + 1, '예외로 끝난 묶음은 기록되지 않는다';
end $$;

-- ---------------------------------------------------------------------------
-- 같은 묶음에서 같은 행을 수천 번 고치면 비용이 제곱으로 는다. 행 하나에 100번까지만 받는다.
-- ID를 다르게 적어도(대문자, 붙임표 없음, 중괄호) 같은 행으로 센다.
-- ---------------------------------------------------------------------------
do $$
declare
  b   uuid := t.id('b');
  lb  uuid := t.id('lb');
  id1 uuid := gen_random_uuid();
  ch  jsonb;
  r   jsonb;
  t0  timestamptz := clock_timestamp();
begin
  select jsonb_agg(jsonb_build_object(
           'table', 'accounts', 'op', 'upsert',
           'id', case g % 4 when 0 then id1::text when 1 then upper(id1::text)
                            when 2 then replace(id1::text, '-', '') else '{' || id1::text || '}' end,
           'base_version', 0, 'client_updated_at', now(), 'data', t.acc('고침 ' || g)) order by g)
    into ch from generate_series(1, 3000) g;
  perform t.login(b);
  r := t.push(lb, ch);
  assert (select count(*) from jsonb_array_elements(r -> 'results') e where e ->> 'status' = 'applied') = 100,
    '같은 행은 한 묶음에 100번까지만 적용한다';
  assert (select count(*) from jsonb_array_elements(r -> 'results') e where e ->> 'status' = 'error') = 2900;
  assert r -> 'results' -> 99 ->> 'status' = 'applied' and (r -> 'results' -> 99 ->> 'version')::int = 100
     and r -> 'results' -> 100 ->> 'status' = 'error', '앞의 100건이 적용된다';
  assert t.row_of('accounts', id1) ->> 'name' = '고침 100' and (t.row_of('accounts', id1) ->> 'version')::int = 100;
  assert clock_timestamp() - t0 < interval '10 seconds', format('너무 오래 걸렸다: %s', clock_timestamp() - t0);
end $$;

-- ---------------------------------------------------------------------------
-- 큰 묶음과 큰 p_limit: 2,100건을 한 번에 넣고, p_limit을 터무니없이 크게 줘도 2,000건까지만 온다.
-- ---------------------------------------------------------------------------
do $$
declare
  u   uuid := t.signup();
  l   uuid := t.ledger_of(u);
  acc uuid := gen_random_uuid();
  ch  jsonb;
  r   jsonb;
  p   jsonb;
begin
  perform t.login(u);
  perform t.push1(l, t.up('accounts', acc, 0, now(), t.acc('통장')));
  select jsonb_agg(t.up('transactions', gen_random_uuid(), 0, now(), t.tx(acc, '대량 ' || g))) into ch
    from generate_series(1, 2100) g;
  r := t.push(l, ch);
  assert (select count(*) from jsonb_array_elements(r -> 'results') e where e ->> 'status' = 'applied') = 2100,
    '2,100건이 모두 적용된다';

  p := public.sync_pull(l, 0, 2147483647);
  assert jsonb_array_length(p -> 'changes') = 2000 and (p ->> 'has_more')::boolean,
    format('p_limit은 2000으로 자른다: %s건', jsonb_array_length(p -> 'changes'));
  p := public.sync_pull(l, 0, 1000000);
  assert jsonb_array_length(p -> 'changes') = 2000;
  p := public.sync_pull(l, 0);
  assert jsonb_array_length(p -> 'changes') = 500 and (p ->> 'has_more')::boolean, '기본값은 500';
  p := public.sync_pull(l, 0, -2147483648);
  assert jsonb_array_length(p -> 'changes') = 1, '가장 작은 정수도 1로';
  p := public.sync_pull(l, 9223372036854775807, 10);
  assert p -> 'changes' = '[]' and (p ->> 'next_seq')::bigint = 9223372036854775807, '가장 큰 커서';
  p := public.sync_pull(l, -9223372036854775808, 10);
  assert jsonb_array_length(p -> 'changes') = 10, '가장 작은 커서';

  -- 이어 받으면 전부 온다: 시드 19 + 자산 1 + 거래 2,100
  p := t.pull_all(l, 0, 2000);
  assert jsonb_array_length(p -> 'changes') = 2120 and (p ->> 'pages')::int = 2,
    format('전체 2,120건: %s건, %s장', jsonb_array_length(p -> 'changes'), p ->> 'pages');
end $$;

-- ---------------------------------------------------------------------------
-- 격리 수준: push는 read committed에서만 돈다. 읽기 전용 트랜잭션 같은 "변경의 잘못이 아닌" 실패는
-- error로 기록하지 않고 묶음 전체를 실패시킨다(기기가 같은 묶음을 다시 보낸다).
-- ---------------------------------------------------------------------------
begin isolation level repeatable read;
do $$
declare
  lb uuid := t.id('lb');
begin
  perform t.login(t.id('b'));
  assert t.sqlstate_of(format('select public.sync_push(%L, %L, %L, %L)', lb, t.dev(1), gen_random_uuid(), '[]')) = '0A000',
    'repeatable read에서는 push를 거부한다';
  assert t.sqlstate_of(format('select public.sync_pull(%L, 0)', lb)) = '00000', 'pull은 된다';
end $$;
rollback;

do $$ begin perform t.set('ro_batch', gen_random_uuid()::text); end $$;

begin read only;
do $$
declare
  lb  uuid := t.id('lb');
  bid uuid := t.id('ro_batch');
begin
  perform t.login(t.id('b'));
  assert t.sqlstate_of(format('select public.sync_push(%L, %L, %L, %L)', lb, t.dev(1), bid,
           jsonb_build_array(t.up('accounts', gen_random_uuid(), 0, now(), t.acc('읽기 전용')))))
         = '25006', '읽기 전용 트랜잭션의 실패는 변경의 error가 아니라 묶음 전체의 예외다';
  assert t.sqlstate_of(format('select public.sync_pull(%L, 0)', lb)) = '00000', 'pull은 읽기 전용에서도 된다';
end $$;
rollback;

do $$
begin
  assert (select count(*) from public.sync_batches where batch_id = t.id('ro_batch')) = 0,
    '실패한 묶음은 기록되지 않아 다시 보낼 수 있다';
end $$;

-- ---------------------------------------------------------------------------
-- 임시 스키마로 이름 가리기: 세션에서 jsonb · uuid 같은 이름의 임시 타입과, ledgers 같은 이름의
-- 임시 테이블을 만들어도 함수 안에서는 진짜가 쓰인다(search_path = pg_catalog, pg_temp).
-- search_path = ''였다면 함수가 테이블 주인의 권한으로 공격자의 코드를 실행한다.
-- 가려 놓은 이름을 시험 자신이 밟지 않도록 여기서는 도우미를 쓰지 않고 이름마다 스키마를 붙인다.
-- ---------------------------------------------------------------------------
begin;
select set_config('t.shadow_user', t.get('b'), true) is not null as ok \gset
set local role authenticated;
select pg_catalog.set_config('request.jwt.claims',
         pg_catalog.json_build_object('sub', pg_catalog.current_setting('t.shadow_user'))::pg_catalog.text, true) is not null as ok \gset

create function pg_temp.evil(v anyelement) returns pg_catalog.bool language plpgsql as $$
begin
  raise exception 'pg_temp의 코드가 %의 권한으로 실행됐다', current_user;
end $$;
create domain pg_temp.jsonb as pg_catalog.jsonb check (pg_temp.evil(value));
create domain pg_temp.uuid as pg_catalog.uuid check (pg_temp.evil(value));
create domain pg_temp.text as pg_catalog.text check (pg_temp.evil(value));
create domain pg_temp.bigint as pg_catalog.int8 check (pg_temp.evil(value));
create domain pg_temp.int8 as pg_catalog.int8 check (pg_temp.evil(value));
create domain pg_temp.integer as pg_catalog.int4 check (pg_temp.evil(value));
create domain pg_temp.int4 as pg_catalog.int4 check (pg_temp.evil(value));
create domain pg_temp.numeric as pg_catalog.numeric check (pg_temp.evil(value));
create domain pg_temp.timestamptz as pg_catalog.timestamptz check (pg_temp.evil(value));
create domain pg_temp.bool as pg_catalog.bool check (pg_temp.evil(value));
create domain pg_temp.boolean as pg_catalog.bool check (pg_temp.evil(value));
create domain pg_temp.interval as pg_catalog.interval check (pg_temp.evil(value));
create domain pg_temp.regclass as pg_catalog.regclass check (pg_temp.evil(value));
create domain pg_temp.regnamespace as pg_catalog.regnamespace check (pg_temp.evil(value));
create temp table ledgers (id pg_catalog.uuid, owner_id pg_catalog.uuid);
create temp table accounts (id pg_catalog.uuid, ledger_id pg_catalog.uuid);
create temp table sync_batches (ledger_id pg_catalog.uuid, batch_id pg_catalog.uuid, result pg_catalog.jsonb);
create temp table pg_class (x pg_catalog.int4);
create temp table pg_attribute (x pg_catalog.int4);

do $$
declare
  l pg_catalog.uuid := pg_catalog.current_setting('t.lb')::pg_catalog.uuid;
  r pg_catalog.jsonb;
begin
  r := public.sync_pull(l, 0::pg_catalog.int8, 5::pg_catalog.int4);
  assert pg_catalog.jsonb_array_length(r -> 'changes') = 5, 'pull이 가려진 이름에 걸렸다';

  r := public.sync_push(l, pg_catalog.gen_random_uuid(), pg_catalog.gen_random_uuid(),
         pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
           'table', 'accounts', 'op', 'upsert', 'id', pg_catalog.gen_random_uuid(),
           'base_version', 0::pg_catalog.int4, 'client_updated_at', pg_catalog.now(),
           'data', pg_catalog.jsonb_build_object('name', '가려 보기', 'kind', 'bank'))));
  assert r #>> '{results,0,status}' = 'applied', 'push가 가려진 이름에 걸렸다';
end $$;
rollback;
