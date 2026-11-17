-- 40_idempotency.sql
-- 멱등: 같은 p_batch_id를 다시 보내면 저장된 결과를 그대로 받고, 아무것도 다시 쓰지 않는다.
\ir _helpers.sql

do $$
declare
  a uuid := t.signup();
  b uuid := t.signup();
begin
  perform t.set('a', a::text);
  perform t.set('la', t.ledger_of(a)::text);
  perform t.set('b', b::text);
  perform t.set('lb', t.ledger_of(b)::text);
  perform t.set('batch', gen_random_uuid()::text);
  perform t.set('acc', gen_random_uuid()::text);
  perform t.set('tx', gen_random_uuid()::text);
  perform t.set('tx2', gen_random_uuid()::text);
end $$;

-- ---------------------------------------------------------------------------
-- 첫 전송
-- ---------------------------------------------------------------------------
do $$
declare
  a  uuid := t.id('a');
  la uuid := t.id('la');
  r  jsonb;
begin
  perform t.login(a);
  r := t.push(la, jsonb_build_array(
         t.up('accounts', t.id('acc'), 0, now(), '{"name": "통장", "kind": "bank"}'),
         t.up('transactions', t.id('tx'), 0, now(), jsonb_build_object(
           'type', 'expense', 'occurred_on', '2026-11-16', 'amount', 1000, 'account_id', t.id('acc')))),
       t.id('batch'), t.dev(1));
  assert r -> 'results' -> 0 ->> 'status' = 'applied' and r -> 'results' -> 1 ->> 'status' = 'applied', format('%s', r);
  perform t.set('first', r::text);
  perform t.set('seq_after_first', t.seq()::text);
end $$;

do $$ begin perform pg_sleep(0.02); end $$;

-- ---------------------------------------------------------------------------
-- 같은 묶음을 다시 보낸다(응답을 못 받은 기기의 재시도).
-- ---------------------------------------------------------------------------
do $$
declare
  a     uuid := t.id('a');
  la    uuid := t.id('la');
  first jsonb := t.get('first')::jsonb;
  seq0  bigint := t.get('seq_after_first')::bigint;
  r     jsonb;
  n     integer;
begin
  assert now() > (first ->> 'server_time')::timestamptz, '재시도는 나중 트랜잭션이다';

  perform t.login(a);
  -- 같은 내용으로 두 번 더 보낸다.
  for n in 1..2 loop
    r := t.push(la, jsonb_build_array(
           t.up('accounts', t.id('acc'), 0, now(), '{"name": "통장", "kind": "bank"}'),
           t.up('transactions', t.id('tx'), 0, now(), jsonb_build_object(
             'type', 'expense', 'occurred_on', '2026-11-16', 'amount', 1000, 'account_id', t.id('acc')))),
         t.id('batch'), t.dev(1));
    assert r = first, format('재전송 %s의 결과가 처음과 다르다: %s <> %s', n, r, first);
  end loop;
  assert r ->> 'server_time' = first ->> 'server_time', 'server_time도 처음 것 그대로다';

  -- 새 번호도 새 버전도 생기지 않았다.
  assert t.seq() = seq0, format('시퀀스가 움직였다: %s → %s', seq0, t.seq());
  assert (t.row_of('accounts', t.id('acc')) ->> 'version')::int = 1, '자산 version은 1 그대로';
  assert (t.row_of('transactions', t.id('tx')) ->> 'version')::int = 1, '거래 version은 1 그대로';
  assert (t.row_of('transactions', t.id('tx')) ->> 'server_seq')::bigint = (first -> 'results' -> 1 ->> 'server_seq')::bigint,
    'server_seq도 그대로';

  -- 내용이나 기기 ID가 달라도 묶음 ID가 같으면 저장된 결과가 온다. 새 내용은 적용되지 않는다.
  r := t.push(la, jsonb_build_array(
         t.up('transactions', t.id('tx'), 1, now(), '{"amount": 999999}'),
         t.up('transactions', t.id('tx2'), 0, now(), jsonb_build_object(
           'type', 'expense', 'occurred_on', '2026-11-16', 'amount', 5, 'account_id', t.id('acc')))),
       t.id('batch'), t.dev(2));
  assert r = first, '묶음 ID가 같으면 내용이 달라도 저장된 결과가 온다';
  assert (t.row_of('transactions', t.id('tx')) ->> 'amount')::bigint = 1000, '금액은 처음 값 그대로';
  assert t.row_of('transactions', t.id('tx2')) is null, '재전송에 끼워 넣은 새 행은 만들어지지 않는다';
  assert t.seq() = seq0, '시퀀스는 여전히 그대로';

  -- 내용을 비워 보내도 묶음 ID가 같으면 저장된 결과가 먼저다.
  assert public.sync_push(la, t.dev(1), t.id('batch'), '[]') = first, '빈 배열로 다시 보내도 같다';

  perform t.logout();
  assert (select count(*) from public.sync_batches where ledger_id = la) = 1, '묶음 기록은 1건';
  assert (select device_id from public.sync_batches where ledger_id = la and batch_id = t.id('batch')) = t.dev(1),
    '기록된 기기는 처음 보낸 기기다';
  assert (select result from public.sync_batches where ledger_id = la and batch_id = t.id('batch')) = first,
    '저장된 결과가 돌려준 결과와 같다';
end $$;

-- ---------------------------------------------------------------------------
-- 묶음 ID는 가계부마다 따로 센다. 다른 가계부가 같은 ID를 써도 서로 상관없다.
-- ---------------------------------------------------------------------------
do $$
declare
  b  uuid := t.id('b');
  lb uuid := t.id('lb');
  r  jsonb;
  x  uuid := gen_random_uuid();
begin
  perform t.login(b);
  r := t.push(lb, jsonb_build_array(t.up('accounts', x, 0, now(), '{"name": "B의 통장", "kind": "bank"}')),
              t.id('batch'), t.dev(3));
  assert r -> 'results' -> 0 ->> 'status' = 'applied' and r -> 'results' -> 0 ->> 'id' = x::text,
    format('B의 묶음은 따로 처리된다: %s', r);
  assert r <> t.get('first')::jsonb, 'A의 결과가 B에게 가면 안 된다';
  assert t.row_of('accounts', x) ->> 'name' = 'B의 통장';
end $$;

-- ---------------------------------------------------------------------------
-- 빈 묶음도 기록되고 멱등이다. 아무것도 쓰지 않았으니 max_server_seq는 null이다.
-- ---------------------------------------------------------------------------
do $$
declare
  a    uuid := t.id('a');
  la   uuid := t.id('la');
  bid  uuid := gen_random_uuid();
  seq0 bigint := t.seq();
  r1   jsonb;
  r2   jsonb;
begin
  perform t.login(a);
  r1 := t.push(la, '[]', bid);
  assert r1 -> 'results' = '[]' and r1 -> 'max_server_seq' = 'null' and r1 ->> 'batch_id' = bid::text,
    format('빈 묶음: %s', r1);
  r2 := t.push(la, '[]', bid);
  assert r1 = r2, '빈 묶음도 멱등이다';
  assert t.seq() = seq0, '빈 묶음은 번호를 쓰지 않는다';
  perform t.logout();
  assert (select count(*) from public.sync_batches where ledger_id = la and batch_id = bid) = 1;
end $$;

-- ---------------------------------------------------------------------------
-- error · conflict 결과도 그대로 다시 온다. 같은 묶음을 다시 보낸다고 다시 시도하지 않는다.
-- ---------------------------------------------------------------------------
do $$
declare
  a    uuid := t.id('a');
  la   uuid := t.id('la');
  bid  uuid := gen_random_uuid();
  acc2 uuid := gen_random_uuid();
  tx3  uuid := gen_random_uuid();
  ch   jsonb;
  r1   jsonb;
  r2   jsonb;
begin
  perform t.login(a);
  ch := jsonb_build_array(
    -- 없는 자산을 가리킨다 → error
    t.up('transactions', tx3, 0, now(), jsonb_build_object(
      'type', 'expense', 'occurred_on', '2026-11-16', 'amount', 1, 'account_id', acc2)),
    -- 낡은 base_version, 더 이른 시각 → conflict_lost
    t.up('transactions', t.id('tx'), 0, now() - interval '1 day', '{"amount": 7}'));
  r1 := t.push(la, ch, bid);
  assert r1 -> 'results' -> 0 ->> 'status' = 'error' and r1 -> 'results' -> 1 ->> 'status' = 'conflict_lost', format('%s', r1);

  -- 그 사이 사정이 바뀐다: 자산이 생기고, 거래가 고쳐진다.
  perform t.push1(la, t.up('accounts', acc2, 0, now(), '{"name": "새 통장", "kind": "bank"}'));
  perform t.push1(la, t.up('transactions', t.id('tx'), 1, now(), '{"amount": 2000}'));

  -- 같은 묶음을 다시 보내도 처음 결과 그대로다(이제는 성공할 내용이어도).
  r2 := t.push(la, ch, bid);
  assert r2 = r1, '저장된 error · conflict_lost 결과가 그대로 온다';
  assert (r2 -> 'results' -> 1 -> 'server_row' ->> 'amount')::bigint = 1000, 'server_row도 그때의 행이다';
  assert t.row_of('transactions', tx3) is null, '다시 시도하지 않으므로 행은 없다';

  -- 새 묶음 ID로 보내면 이제는 적용된다.
  r2 := t.push(la, jsonb_build_array(ch -> 0));
  assert r2 -> 'results' -> 0 ->> 'status' = 'applied', format('새 묶음으로는 적용된다: %s', r2);
end $$;
