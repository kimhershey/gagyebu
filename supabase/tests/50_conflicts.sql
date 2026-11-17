-- 50_conflicts.sql
-- 충돌 판정(README의 표 한 줄씩), 삭제 표시와 되살리기, 미래 시각 자르기, 같은 묶음 안의 같은 행.
\ir _helpers.sql

do $$
declare
  u uuid := t.signup();
begin
  perform t.set('u', u::text);
  perform t.set('l', t.ledger_of(u)::text);
end $$;

-- ---------------------------------------------------------------------------
-- 서버에 없는 행
-- ---------------------------------------------------------------------------
do $$
declare
  u    uuid := t.id('u');
  l    uuid := t.id('l');
  id1  uuid := gen_random_uuid();
  id2  uuid := gen_random_uuid();
  id3  uuid := gen_random_uuid();
  seq0 bigint;
  r    jsonb;
  x    jsonb;
begin
  perform t.login(u);

  -- 없음 + upsert → 새로 넣는다. version = 1, applied
  seq0 := t.seq();
  x := t.push1(l, t.up('accounts', id1, 0, now() - interval '10 minutes', t.acc('새 통장')));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 1, format('없음+upsert: %s', x);
  assert (x ->> 'server_seq')::bigint = seq0 + 1 and x -> 'server_row' = 'null' and x -> 'error' = 'null', format('%s', x);
  assert t.row_of('accounts', id1) ->> 'name' = '새 통장' and (t.row_of('accounts', id1) ->> 'version')::int = 1;

  -- base_version이 0이 아니어도 서버에 없으면 새로 넣는다(version은 1부터).
  x := t.push1(l, t.up('accounts', id2, 7, now() - interval '10 minutes', t.acc('서버가 모르는 행')));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 1, format('없음+upsert(base 7): %s', x);

  -- 없음 + delete → 할 일이 없다. applied, version = 0, 아무것도 쓰지 않는다
  seq0 := t.seq();
  r := t.push(l, jsonb_build_array(t.del('accounts', id3, 3, now())));
  x := r -> 'results' -> 0;
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 0, format('없음+delete: %s', x);
  assert x -> 'server_seq' = 'null' and x -> 'server_row' = 'null' and x -> 'error' = 'null', format('%s', x);
  assert r -> 'max_server_seq' = 'null', '아무것도 쓰지 않았으면 max_server_seq는 null';
  assert t.seq() = seq0, '번호를 쓰지 않는다';
  assert t.row_of('accounts', id3) is null, '행이 생기지 않는다';
end $$;

-- ---------------------------------------------------------------------------
-- 서버에 있는 행, base_version = version → 적용
-- ---------------------------------------------------------------------------
do $$
declare
  u    uuid := t.id('u');
  l    uuid := t.id('l');
  id1  uuid := gen_random_uuid();
  cur  bigint;
  seq1 bigint;
  x    jsonb;
  row1 jsonb;
  p    jsonb;
begin
  perform t.login(u);
  x := t.push1(l, t.up('accounts', id1, 0, now() - interval '10 minutes', t.acc('처음')));
  seq1 := (x ->> 'server_seq')::bigint;
  cur := seq1;  -- 기기 2가 여기까지 받았다고 하자

  -- upsert: 들어온 시각이 서버 행보다 이르더라도 버전이 맞으면 적용한다.
  x := t.push1(l, t.up('accounts', id1, 1, now() - interval '50 minutes', t.acc('고침')));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 2, format('있음+base 일치: %s', x);
  assert (x ->> 'server_seq')::bigint > seq1 and x -> 'server_row' = 'null', format('%s', x);
  row1 := t.row_of('accounts', id1);
  assert row1 ->> 'name' = '고침' and (row1 ->> 'version')::int = 2 and row1 -> 'deleted_at' = 'null';
  assert (row1 ->> 'client_updated_at')::timestamptz = now() - interval '50 minutes', 'client_updated_at은 들어온 값';
  assert (row1 ->> 'updated_at')::timestamptz = now(), 'updated_at은 서버 시각';

  -- delete: 삭제 표시를 쓴다. version + 1
  x := t.push1(l, t.del('accounts', id1, 2, now() - interval '5 minutes'));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 3 and x -> 'server_row' = 'null', format('delete: %s', x);
  row1 := t.row_of('accounts', id1);
  assert row1 is not null, '행은 남아 있다(삭제 표시)';
  assert (row1 ->> 'deleted_at')::timestamptz = now() and (row1 ->> 'updated_at')::timestamptz = now(),
    format('deleted_at = updated_at = 서버 시각: %s', row1);
  assert (row1 ->> 'version')::int = 3 and row1 ->> 'name' = '고침', '삭제 표시는 내용을 건드리지 않는다';

  -- 기기 2가 pull하면 삭제 표시가 있는 행을 받는다.
  p := public.sync_pull(l, cur);
  assert jsonb_array_length(p -> 'changes') = 1, format('삭제 표시 1행: %s', p);
  assert p -> 'changes' -> 0 ->> 'table' = 'accounts' and p -> 'changes' -> 0 -> 'row' ->> 'id' = id1::text
     and p -> 'changes' -> 0 -> 'row' ->> 'deleted_at' is not null
     and (p -> 'changes' -> 0 -> 'row' ->> 'version')::int = 3, format('pull한 삭제 표시: %s', p);

  -- 이미 삭제 표시가 있는 행을 또 지워도 규칙은 같다: 버전이 맞으면 적용, version + 1
  x := t.push1(l, t.del('accounts', id1, 3, now() - interval '4 minutes'));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 4, format('거듭 삭제: %s', x);

  -- 삭제 표시가 있는 행을 upsert하면 되살아난다(삭제 표시를 지운다).
  x := t.push1(l, t.up('accounts', id1, 4, now() - interval '3 minutes', '{"name": "되살림"}'));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 5, format('되살리기: %s', x);
  row1 := t.row_of('accounts', id1);
  assert row1 -> 'deleted_at' = 'null' and row1 ->> 'name' = '되살림' and row1 ->> 'kind' = 'bank',
    format('되살아난 행: %s', row1);
  p := public.sync_pull(l, cur);
  assert jsonb_array_length(p -> 'changes') = 1 and p -> 'changes' -> 0 -> 'row' -> 'deleted_at' = 'null'
     and (p -> 'changes' -> 0 -> 'row' ->> 'version')::int = 5, format('pull한 되살아난 행: %s', p);
end $$;

-- ---------------------------------------------------------------------------
-- 서버에 있는 행, base_version <> version → 시각으로 가른다
-- ---------------------------------------------------------------------------
do $$
declare
  u    uuid := t.id('u');
  l    uuid := t.id('l');
  id1  uuid := gen_random_uuid();
  seq0 bigint;
  r    jsonb;
  x    jsonb;
  before_row jsonb;
  row1 jsonb;
begin
  perform t.login(u);
  -- 기기 1이 만들고(v1) 한 번 고친다(v2, 20분 전).
  perform t.push1(l, t.up('accounts', id1, 0, now() - interval '30 minutes', t.acc('v1')), t.dev(1));
  perform t.push1(l, t.up('accounts', id1, 1, now() - interval '20 minutes', t.acc('v2 기기1')), t.dev(1));
  before_row := t.row_of('accounts', id1);

  -- 기기 2는 v1만 안다. 더 늦은 시각(10분 전)에 고쳤다 → conflict_won
  x := t.push1(l, t.up('accounts', id1, 1, now() - interval '10 minutes', t.acc('v3 기기2')), t.dev(2));
  assert x ->> 'status' = 'conflict_won' and (x ->> 'version')::int = 3, format('늦은 쪽이 이긴다: %s', x);
  assert x -> 'server_row' = before_row, format('server_row는 덮어쓰기 전 행: %s', x -> 'server_row');
  assert x -> 'server_row' ->> 'name' = 'v2 기기1' and (x -> 'server_row' ->> 'version')::int = 2;
  assert (x ->> 'server_seq')::bigint > (before_row ->> 'server_seq')::bigint and x -> 'error' = 'null';
  row1 := t.row_of('accounts', id1);
  assert row1 ->> 'name' = 'v3 기기2' and (row1 ->> 'version')::int = 3
     and (row1 ->> 'client_updated_at')::timestamptz = now() - interval '10 minutes', format('%s', row1);

  -- 기기 3도 v1만 안다. 더 이른 시각(25분 전)에 고쳤다 → conflict_lost, 아무것도 쓰지 않는다
  seq0 := t.seq();
  r := t.push(l, jsonb_build_array(t.up('accounts', id1, 1, now() - interval '25 minutes', t.acc('v? 기기3'))),
              gen_random_uuid(), t.dev(3));
  x := r -> 'results' -> 0;
  assert x ->> 'status' = 'conflict_lost', format('이른 쪽이 진다: %s', x);
  assert x -> 'server_row' = row1, format('server_row는 현재 행: %s', x -> 'server_row');
  assert (x ->> 'version')::int = 3 and (x ->> 'server_seq')::bigint = (row1 ->> 'server_seq')::bigint,
    'conflict_lost의 version · server_seq는 서버 행의 값';
  assert x -> 'error' = 'null' and r -> 'max_server_seq' = 'null', format('%s', r);
  assert t.seq() = seq0, '진 변경은 번호를 쓰지 않는다';
  assert t.row_of('accounts', id1) = row1, '행은 그대로다';

  -- 시각이 같으면 "늦다"가 아니다 → conflict_lost
  x := t.push1(l, t.up('accounts', id1, 1, now() - interval '10 minutes', t.acc('동시각')), t.dev(3));
  assert x ->> 'status' = 'conflict_lost', format('같은 시각은 진다: %s', x);
  assert t.row_of('accounts', id1) = row1;

  -- base_version이 서버보다 큰 경우도 "다르다"이다.
  x := t.push1(l, t.up('accounts', id1, 99, now() - interval '25 minutes', t.acc('미래 버전')), t.dev(3));
  assert x ->> 'status' = 'conflict_lost', format('base가 더 커도 충돌이다: %s', x);
  x := t.push1(l, t.up('accounts', id1, 99, now() - interval '9 minutes', t.acc('미래 버전, 늦은 시각')), t.dev(3));
  assert x ->> 'status' = 'conflict_won' and (x ->> 'version')::int = 4, format('%s', x);
end $$;

-- ---------------------------------------------------------------------------
-- 삭제가 끼어든 충돌
-- ---------------------------------------------------------------------------
do $$
declare
  u    uuid := t.id('u');
  l    uuid := t.id('l');
  id1  uuid := gen_random_uuid();
  id2  uuid := gen_random_uuid();
  x    jsonb;
  row1 jsonb;
begin
  perform t.login(u);

  -- 낡은 delete, 더 이른 시각 → conflict_lost. 행은 살아 있다.
  perform t.push1(l, t.up('accounts', id1, 0, now() - interval '30 minutes', t.acc('v1')));
  perform t.push1(l, t.up('accounts', id1, 1, now() - interval '20 minutes', t.acc('v2')));
  row1 := t.row_of('accounts', id1);
  x := t.push1(l, t.del('accounts', id1, 1, now() - interval '25 minutes'), t.dev(2));
  assert x ->> 'status' = 'conflict_lost' and x -> 'server_row' = row1, format('이른 delete는 진다: %s', x);
  assert t.row_of('accounts', id1) -> 'deleted_at' = 'null', '행은 살아 있다';

  -- 낡은 delete, 더 늦은 시각 → conflict_won. 삭제 표시가 생기고 server_row는 지우기 전 행이다.
  x := t.push1(l, t.del('accounts', id1, 1, now() - interval '15 minutes'), t.dev(2));
  assert x ->> 'status' = 'conflict_won' and (x ->> 'version')::int = 3, format('늦은 delete는 이긴다: %s', x);
  assert x -> 'server_row' = row1 and x -> 'server_row' -> 'deleted_at' = 'null', 'server_row는 지우기 전 행';
  row1 := t.row_of('accounts', id1);
  assert row1 ->> 'deleted_at' is not null, '삭제 표시가 생겼다';

  -- 삭제 표시(15분 전)보다 이른 낡은 upsert → conflict_lost. server_row로 삭제 표시를 알려 준다.
  x := t.push1(l, t.up('accounts', id1, 2, now() - interval '18 minutes', t.acc('뒤늦은 수정')), t.dev(3));
  assert x ->> 'status' = 'conflict_lost' and x -> 'server_row' = row1
     and x -> 'server_row' ->> 'deleted_at' is not null, format('삭제 뒤의 이른 upsert는 진다: %s', x);
  assert t.row_of('accounts', id1) = row1, '삭제 표시는 그대로다';

  -- 삭제 표시보다 늦은 낡은 upsert → conflict_won. 되살아나고 server_row는 삭제 표시가 있던 행이다.
  x := t.push1(l, t.up('accounts', id1, 2, now() - interval '5 minutes', t.acc('삭제 뒤에 고침')), t.dev(3));
  assert x ->> 'status' = 'conflict_won' and (x ->> 'version')::int = 4, format('삭제 뒤의 늦은 upsert는 이긴다: %s', x);
  assert x -> 'server_row' = row1 and x -> 'server_row' ->> 'deleted_at' is not null;
  assert t.row_of('accounts', id1) -> 'deleted_at' = 'null' and t.row_of('accounts', id1) ->> 'name' = '삭제 뒤에 고침';

  -- 다른 테이블(거래)에서도 같다: 삭제 → pull → 되살리기
  perform t.push1(l, t.up('transactions', id2, 0, now() - interval '30 minutes', jsonb_build_object(
    'type', 'expense', 'occurred_on', '2026-11-16', 'amount', 3000, 'account_id', id1, 'memo', '커피')));
  x := t.push1(l, t.del('transactions', id2, 1, now() - interval '20 minutes'));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 2;
  x := t.find(t.pull_all(l) -> 'changes', 'transactions', id2);
  assert x ->> 'deleted_at' is not null and x ->> 'memo' = '커피', format('거래의 삭제 표시가 내려온다: %s', x);
  x := t.push1(l, t.up('transactions', id2, 2, now() - interval '10 minutes', '{"memo": "커피(되살림)"}'));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 3;
  x := t.find(t.pull_all(l) -> 'changes', 'transactions', id2);
  assert x -> 'deleted_at' = 'null' and x ->> 'memo' = '커피(되살림)' and x -> 'amount' = '3000', format('되살아난 거래: %s', x);
end $$;

-- ---------------------------------------------------------------------------
-- ledgers · profiles도 같은 규칙이다. ledgers의 server_row에는 ledger_id 키가 없다.
-- ---------------------------------------------------------------------------
do $$
declare
  u uuid := t.id('u');
  l uuid := t.id('l');
  x jsonb;
begin
  perform t.login(u);
  x := t.push1(l, t.up('ledgers', l, 1, now() - interval '10 minutes', '{"name": "기기1의 이름"}'), t.dev(1));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 2, format('%s', x);

  x := t.push1(l, t.up('ledgers', l, 1, now() - interval '20 minutes', '{"name": "기기2의 이름"}'), t.dev(2));
  assert x ->> 'status' = 'conflict_lost' and x -> 'server_row' ->> 'name' = '기기1의 이름'
     and not (x -> 'server_row' ? 'ledger_id') and x -> 'server_row' ->> 'id' = l::text, format('%s', x);

  x := t.push1(l, t.up('ledgers', l, 1, now() - interval '5 minutes', '{"name": "기기2의 이름", "currency": "USD"}'), t.dev(2));
  assert x ->> 'status' = 'conflict_won' and (x ->> 'version')::int = 3
     and x -> 'server_row' ->> 'name' = '기기1의 이름', format('%s', x);
  assert t.row_of('ledgers', l) ->> 'name' = '기기2의 이름' and t.row_of('ledgers', l) ->> 'currency' = 'USD';

  x := t.push1(l, t.up('profiles', u, 1, now() - interval '10 minutes', '{"display_name": "기기1"}'), t.dev(1));
  assert x ->> 'status' = 'applied' and (x ->> 'version')::int = 2, format('%s', x);
  x := t.push1(l, t.up('profiles', u, 1, now() - interval '20 minutes', '{"display_name": "기기2"}'), t.dev(2));
  assert x ->> 'status' = 'conflict_lost' and x -> 'server_row' ->> 'display_name' = '기기1', format('%s', x);
end $$;

-- ---------------------------------------------------------------------------
-- 미래 시각 자르기: 시계가 하루 빠른 기기가 계속 이기면 안 된다.
-- 트랜잭션마다 서버 시각이 달라야 하므로 블록을 나눈다.
-- ---------------------------------------------------------------------------
do $$
declare
  u   uuid := t.id('u');
  l   uuid := t.id('l');
  id1 uuid := gen_random_uuid();
  x   jsonb;
  r   jsonb;
begin
  perform t.set('clamp_id', id1::text);
  perform t.login(u);
  -- 기기 X(시계가 하루 빠르다)가 행을 만들고 한 번 고친다.
  perform t.push1(l, t.up('accounts', id1, 0, now() + interval '1 day', t.acc('X가 만듦')), t.dev(1));
  r := t.push(l, jsonb_build_array(t.up('accounts', id1, 1, now() + interval '1 day', t.acc('X가 고침'))),
              gen_random_uuid(), t.dev(1));
  assert r -> 'results' -> 0 ->> 'status' = 'applied';
  x := t.row_of('accounts', id1);
  -- 저장된 client_updated_at은 서버 시각으로 잘렸다.
  assert (x ->> 'client_updated_at')::timestamptz = (r ->> 'server_time')::timestamptz,
    format('미래 시각은 서버 시각으로 자른다: %s (server_time %s)', x ->> 'client_updated_at', r ->> 'server_time');
  assert (x ->> 'client_updated_at')::timestamptz <= clock_timestamp(), '저장된 시각이 미래면 안 된다';
end $$;

do $$ begin perform pg_sleep(0.02); end $$;

do $$
declare
  u   uuid := t.id('u');
  l   uuid := t.id('l');
  id1 uuid := t.id('clamp_id');
  x   jsonb;
begin
  perform t.login(u);
  -- 기기 Y(시계가 맞다)는 v1만 안다. X가 push한 뒤에 고쳤다 → 이겨야 한다.
  -- 자르지 않았다면 X의 시각(내일)이 남아 Y는 하루 동안 계속 진다.
  x := t.push1(l, t.up('accounts', id1, 1, clock_timestamp(), t.acc('Y가 고침')), t.dev(2));
  assert x ->> 'status' = 'conflict_won', format('시계가 맞는 기기의 나중 수정이 이겨야 한다: %s', x);
  assert x -> 'server_row' ->> 'name' = 'X가 고침' and t.row_of('accounts', id1) ->> 'name' = 'Y가 고침';

  -- Y가 X의 push보다 먼저 고친 것이었다면 진다(X의 수정이 서버에 더 늦게 닿았다).
  x := t.push1(l, t.up('accounts', id1, 1, now() - interval '1 hour', t.acc('Y의 옛 수정')), t.dev(2));
  assert x ->> 'status' = 'conflict_lost', format('%s', x);
end $$;

do $$ begin perform pg_sleep(0.02); end $$;

do $$
declare
  u   uuid := t.id('u');
  l   uuid := t.id('l');
  id1 uuid := t.id('clamp_id');
  x   jsonb;
  p   jsonb;
begin
  perform t.login(u);
  -- X가 낡은 버전으로 또 보낸다. 내일 시각이라도 지금으로 잘리고, 지금은 Y의 수정보다 늦다 → 이긴다.
  x := t.push1(l, t.up('accounts', id1, 2, now() + interval '1 day', t.acc('X가 또 고침')), t.dev(1));
  assert x ->> 'status' = 'conflict_won', format('%s', x);
  -- 아주 먼 미래도 똑같이 잘린다.
  x := t.push1(l, t.up('accounts', id1, 4, '9999-12-31T00:00:00Z', t.acc('먼 미래')), t.dev(1));
  assert x ->> 'status' = 'applied';
  assert (t.row_of('accounts', id1) ->> 'client_updated_at')::timestamptz = now(), '먼 미래도 서버 시각으로 자른다';

  -- 어떤 행도 server_time보다 앞선 client_updated_at을 갖지 않는다.
  p := t.pull_all(l);
  assert (select bool_and((e -> 'row' ->> 'client_updated_at')::timestamptz <= now())
            from jsonb_array_elements(p -> 'changes') e), '미래의 client_updated_at이 남아 있다';
end $$;

-- ---------------------------------------------------------------------------
-- 같은 묶음 안에서 같은 행을 두 번 고친다.
-- 앞 변경이 적용됐으면 뒤 변경은 보낸 순서대로 이어서 적용한다. 기기는 앞 변경의 새 버전을 모르므로
-- base_version이 같을 수밖에 없고, 시각이 같거나(같은 밀리초, 둘 다 미래라 잘림) 뒤집혀도 뒤 변경이 남아야 한다.
-- ---------------------------------------------------------------------------
do $$
declare
  u   uuid := t.id('u');
  l   uuid := t.id('l');
  id1 uuid := gen_random_uuid();
  id2 uuid := gen_random_uuid();
  id3 uuid := gen_random_uuid();
  id4 uuid := gen_random_uuid();
  id5 uuid := gen_random_uuid();
  id6 uuid := gen_random_uuid();
  at  timestamptz := now() - interval '10 minutes';
  r   jsonb;
  x   jsonb;
begin
  perform t.login(u);

  -- 새 행을 만들고 바로 고친다(시각이 같다).
  r := t.push(l, jsonb_build_array(
         t.up('accounts', id1, 0, at, t.acc('만듦')),
         t.up('accounts', id1, 0, at, t.acc('바로 고침'))));
  assert r -> 'results' -> 0 ->> 'status' = 'applied' and (r -> 'results' -> 0 ->> 'version')::int = 1, format('%s', r);
  assert r -> 'results' -> 1 ->> 'status' = 'applied' and (r -> 'results' -> 1 ->> 'version')::int = 2, format('%s', r);
  assert (r -> 'results' -> 1 ->> 'server_seq')::bigint > (r -> 'results' -> 0 ->> 'server_seq')::bigint
     and (r ->> 'max_server_seq')::bigint = (r -> 'results' -> 1 ->> 'server_seq')::bigint;
  assert t.row_of('accounts', id1) ->> 'name' = '바로 고침', '뒤 변경이 남는다';

  -- 만들고 바로 지운다 → 삭제 표시
  r := t.push(l, jsonb_build_array(
         t.up('accounts', id2, 0, at, t.acc('만들었다 지움')),
         t.del('accounts', id2, 0, at)));
  assert r -> 'results' -> 1 ->> 'status' = 'applied' and (r -> 'results' -> 1 ->> 'version')::int = 2, format('%s', r);
  assert t.row_of('accounts', id2) ->> 'deleted_at' is not null, '지운 것이 남는다';

  -- 지웠다가 되살린다 → 살아 있다
  r := t.push(l, jsonb_build_array(
         t.del('accounts', id1, 2, at),
         t.up('accounts', id1, 2, at, t.acc('지웠다 되살림'))));
  assert r -> 'results' -> 0 ->> 'status' = 'applied' and r -> 'results' -> 1 ->> 'status' = 'applied'
     and (r -> 'results' -> 1 ->> 'version')::int = 4, format('%s', r);
  assert t.row_of('accounts', id1) -> 'deleted_at' = 'null' and t.row_of('accounts', id1) ->> 'name' = '지웠다 되살림';

  -- 시계가 빠른 기기: 두 변경 모두 서버 시각으로 잘려 시각이 같아진다. 그래도 둘 다 적용한다.
  r := t.push(l, jsonb_build_array(
         t.up('accounts', id3, 0, now() + interval '1 day', t.acc('빠른 시계 1')),
         t.up('accounts', id3, 0, now() + interval '1 day' + interval '1 minute', t.acc('빠른 시계 2')),
         t.del('accounts', id3, 0, now() + interval '1 day' + interval '2 minutes')));
  assert (select bool_and(e ->> 'status' = 'applied') from jsonb_array_elements(r -> 'results') e), format('%s', r);
  assert (r -> 'results' -> 2 ->> 'version')::int = 3 and t.row_of('accounts', id3) ->> 'deleted_at' is not null
     and t.row_of('accounts', id3) ->> 'name' = '빠른 시계 2', '마지막 변경(삭제)까지 순서대로 적용된다';

  -- 뒤 변경의 시각이 더 이르더라도(기기 시계가 뒤로 갔다) 보낸 순서를 따른다.
  r := t.push(l, jsonb_build_array(
         t.up('accounts', id4, 0, at, t.acc('먼저')),
         t.up('accounts', id4, 0, at - interval '1 hour', t.acc('나중'))));
  assert r -> 'results' -> 1 ->> 'status' = 'applied' and t.row_of('accounts', id4) ->> 'name' = '나중', format('%s', r);

  -- 앞 변경이 충돌에서 이겼어도 그 뒤는 이어서 적용한다.
  perform t.push1(l, t.up('accounts', id5, 0, at - interval '2 hours', t.acc('v1')));
  perform t.push1(l, t.up('accounts', id5, 1, at - interval '1 hour', t.acc('v2')));
  r := t.push(l, jsonb_build_array(
         t.up('accounts', id5, 1, at, t.acc('낡았지만 늦음')),
         t.up('accounts', id5, 1, at - interval '3 hours', t.acc('그다음'))), gen_random_uuid(), t.dev(2));
  assert r -> 'results' -> 0 ->> 'status' = 'conflict_won' and r -> 'results' -> 1 ->> 'status' = 'applied'
     and (r -> 'results' -> 1 ->> 'version')::int = 4, format('%s', r);
  assert t.row_of('accounts', id5) ->> 'name' = '그다음';

  -- 앞 변경이 충돌에서 졌다면 이 묶음은 그 행을 쓴 적이 없다. 뒤 변경은 평소 규칙대로 판정한다.
  r := t.push(l, jsonb_build_array(
         t.up('accounts', id5, 1, at - interval '5 hours', t.acc('낡고 이름')),
         t.up('accounts', id5, 1, at - interval '4 hours', t.acc('여전히 이름')),
         t.up('accounts', id5, 1, now(), t.acc('낡았지만 지금'))), gen_random_uuid(), t.dev(3));
  assert r -> 'results' -> 0 ->> 'status' = 'conflict_lost' and r -> 'results' -> 1 ->> 'status' = 'conflict_lost'
     and r -> 'results' -> 2 ->> 'status' = 'conflict_won', format('%s', r);

  -- 앞 변경이 실패(error)했으면 뒤 변경은 새 행으로 판정한다.
  r := t.push(l, jsonb_build_array(
         t.up('accounts', id6, 0, at, '{"name": "종류가 틀림", "kind": "piggy"}'),
         t.up('accounts', id6, 0, at, t.acc('바로잡음'))));
  assert r -> 'results' -> 0 ->> 'status' = 'error' and r -> 'results' -> 1 ->> 'status' = 'applied'
     and (r -> 'results' -> 1 ->> 'version')::int = 1, format('%s', r);
end $$;
