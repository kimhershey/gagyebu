-- 90_realtime.sql
-- 실시간 변경 신호: push가 무언가를 쓰면 비공개 채널 'ledger:<ledger_id>'로 'changed' 신호를 보낸다.
-- 스텁의 realtime 스키마(realtime.send, realtime.messages)를 상대로 본다. 진짜 Realtime 서버는 없다.
\ir _helpers.sql

do $$
declare
  a uuid := t.signup();
  b uuid := t.signup();
begin
  assert to_regprocedure('realtime.send(jsonb,text,text,boolean)') is not null,
    '이 시험은 스텁의 realtime 스키마가 있어야 한다';
  perform t.set('a', a::text);
  perform t.set('la', t.ledger_of(a)::text);
  perform t.set('b', b::text);
  perform t.set('lb', t.ledger_of(b)::text);
  perform t.set('acc', gen_random_uuid()::text);
end $$;

-- ---------------------------------------------------------------------------
-- 무언가를 쓴 push는 신호를 하나 보낸다. 내용은 마지막 server_seq뿐이다.
-- ---------------------------------------------------------------------------
do $$
declare
  a     uuid := t.id('a');
  la    uuid := t.id('la');
  v_topic text := 'ledger:' || t.get('la');
  n0    bigint;
  r     jsonb;
  m     record;
  bid   uuid := gen_random_uuid();
begin
  select count(*) into n0 from realtime.messages;

  perform t.login(a);
  r := t.push(la, jsonb_build_array(
         t.up('accounts', t.id('acc'), 0, now(), t.acc('통장')),
         t.up('accounts', gen_random_uuid(), 0, now(), t.acc('통장 2'))), bid);
  assert (r ->> 'max_server_seq') is not null;
  perform t.logout();

  assert (select count(*) from realtime.messages) = n0 + 1, '쓴 push 하나에 신호 하나';
  select * into m from realtime.messages x where x.topic = v_topic;
  assert m.topic = 'ledger:' || la::text, format('주제: %s', m.topic);
  assert m.event = 'changed', format('이벤트: %s', m.event);
  assert m.payload = jsonb_build_object('server_seq', (r ->> 'max_server_seq')::bigint), format('내용: %s', m.payload);
  assert m.private, '비공개 채널로 보낸다';
  assert m.extension = 'broadcast';

  -- 같은 묶음을 다시 보내면(멱등) 신호도 다시 보내지 않는다.
  perform t.login(a);
  perform t.push(la, '[]', bid);
  perform t.logout();
  assert (select count(*) from realtime.messages) = n0 + 1, '재전송은 신호를 보내지 않는다';

  -- 아무것도 쓰지 않은 push(빈 묶음, 진 충돌, 없는 행 삭제, 실패한 변경)는 신호를 보내지 않는다.
  perform t.login(a);
  r := t.push(la, '[]');
  r := t.push(la, jsonb_build_array(
         t.up('accounts', t.id('acc'), 0, now() - interval '1 day', t.acc('낡고 이른 수정')),
         t.del('accounts', gen_random_uuid(), 0, now()),
         t.up('accounts', gen_random_uuid(), 0, now(), '{"name": "종류가 틀림", "kind": "piggy"}')));
  assert r -> 'max_server_seq' = 'null'
     and r -> 'results' -> 0 ->> 'status' = 'conflict_lost' and r -> 'results' -> 1 ->> 'status' = 'applied'
     and r -> 'results' -> 2 ->> 'status' = 'error', format('%s', r);
  perform t.logout();
  assert (select count(*) from realtime.messages) = n0 + 1, '쓴 것이 없으면 신호도 없다';

  -- 다른 가계부의 push는 그 가계부의 주제로 간다.
  perform t.login(t.id('b'));
  perform t.push1(t.id('lb'), t.up('accounts', gen_random_uuid(), 0, now(), t.acc('B의 통장')));
  perform t.logout();
  assert (select count(*) from realtime.messages where topic = 'ledger:' || t.get('lb')) = 1
     and (select count(*) from realtime.messages where topic = 'ledger:' || t.get('la')) = 1, '주제는 가계부마다 다르다';
end $$;

-- ---------------------------------------------------------------------------
-- 채널 정책: 가계부의 주인만 자기 채널의 신호를 읽는다.
-- Realtime 서버는 비공개 채널에 들어오는 사용자의 역할 · 토큰 · 주제(realtime.topic)를 걸고
-- realtime.messages의 조회 정책을 평가한다. 그 조건을 그대로 흉내 낸다.
-- ---------------------------------------------------------------------------
do $$
begin
  assert (select count(*) from pg_policies
           where schemaname = 'realtime' and tablename = 'messages' and policyname = 'ledger_signal_select_own'
             and cmd = 'SELECT' and roles = '{authenticated}') = 1, '0002가 채널 정책을 만들었어야 한다';
  assert (select count(*) from pg_policies where schemaname = 'realtime' and tablename = 'messages' and cmd <> 'SELECT') = 0,
    '보내기(insert) 정책은 없다. 기기는 이 채널로 신호를 보낼 수 없다';
end $$;

do $$
declare
  a  uuid := t.id('a');
  b  uuid := t.id('b');
  ta text := 'ledger:' || t.get('la');
  tb text := 'ledger:' || t.get('lb');
begin
  -- A가 자기 채널에 들어온다 → 읽을 수 있다.
  perform t.login(a);
  perform set_config('realtime.topic', ta, true);
  assert (select count(*) from realtime.messages) = 1 and (select topic from realtime.messages) = ta,
    'A는 자기 채널의 신호만 읽는다';

  -- A가 B의 채널에 들어오려 한다 → 아무것도 못 읽는다(입장이 거부된다).
  perform set_config('realtime.topic', tb, true);
  assert (select count(*) from realtime.messages) = 0, 'A는 B의 채널을 못 읽는다';
  -- 주제 없이, 또는 엉뚱한 주제로도 마찬가지다.
  perform set_config('realtime.topic', '', true);
  assert (select count(*) from realtime.messages) = 0, '주제가 없으면 못 읽는다';
  perform set_config('realtime.topic', 'ledger:' || gen_random_uuid()::text, true);
  assert (select count(*) from realtime.messages) = 0, '없는 가계부의 채널도 못 읽는다';
  perform set_config('realtime.topic', upper(ta), true);
  assert (select count(*) from realtime.messages) = 0, '주제는 소문자 UUID 그대로여야 한다';

  -- 기기는 이 채널로 신호를 직접 보낼 수 없다(가짜 신호를 만들 수 없다).
  perform set_config('realtime.topic', ta, true);
  assert t.sqlstate_of(format(
    $q$insert into realtime.messages (topic, extension, event, payload, private)
       values (%L, 'broadcast', 'changed', '{"server_seq": 1}', true)$q$, ta)) = '42501', '기기의 insert는 RLS가 막는다';
  perform t.logout();

  -- B는 자기 채널만.
  perform t.login(b);
  perform set_config('realtime.topic', tb, true);
  assert (select count(*) from realtime.messages) = 1 and (select topic from realtime.messages) = tb,
    'B는 자기 채널의 신호만 읽는다';
  perform set_config('realtime.topic', ta, true);
  assert (select count(*) from realtime.messages) = 0, 'B는 A의 채널을 못 읽는다';
  perform t.logout();

  -- anon은 주제를 알아도 못 읽는다.
  perform t.login_anon();
  perform set_config('realtime.topic', ta, true);
  assert (select count(*) from realtime.messages) = 0, 'anon은 못 읽는다';
end $$;

-- ---------------------------------------------------------------------------
-- 신호가 실패해도 push는 성공한다. realtime.send()가 없어도 마찬가지다(Realtime이 없는 PostgreSQL).
-- 트랜잭션 안에서 함수를 망가뜨려 보고 되돌린다.
-- ---------------------------------------------------------------------------
begin;
create or replace function realtime.send(payload jsonb, event text, topic text, private boolean default true)
returns void language plpgsql as $$
begin
  raise exception 'realtime이 고장 났다';
end $$;

do $$
declare
  a   uuid := t.id('a');
  la  uuid := t.id('la');
  id1 uuid := gen_random_uuid();
  bid uuid := gen_random_uuid();
  r   jsonb;
  n0  bigint;
begin
  select count(*) into n0 from realtime.messages;
  perform t.login(a);
  r := t.push(la, jsonb_build_array(t.up('accounts', id1, 0, now(), t.acc('신호 없이도'))), bid);
  assert r -> 'results' -> 0 ->> 'status' = 'applied', format('신호가 실패해도 적용돼야 한다: %s', r);
  assert t.row_of('accounts', id1) ->> 'name' = '신호 없이도', '행이 써졌다';
  -- 묶음도 기록돼 멱등이 유지된다.
  assert t.push(la, '[]', bid) = r, '신호가 실패한 묶음도 저장된다';
  perform t.logout();
  assert (select count(*) from realtime.messages) = n0, '신호는 가지 않았다';
end $$;
rollback;

begin;
alter function realtime.send(jsonb, text, text, boolean) rename to send_renamed_away;

do $$
declare
  a   uuid := t.id('a');
  la  uuid := t.id('la');
  id1 uuid := gen_random_uuid();
  r   jsonb;
  n0  bigint;
begin
  assert to_regprocedure('realtime.send(jsonb,text,text,boolean)') is null, 'realtime.send가 없는 상태';
  select count(*) into n0 from realtime.messages;
  perform t.login(a);
  r := t.push(la, jsonb_build_array(t.up('accounts', id1, 0, now(), t.acc('realtime 없이'))));
  assert r -> 'results' -> 0 ->> 'status' = 'applied', format('realtime.send가 없어도 적용돼야 한다: %s', r);
  perform t.logout();
  assert (select count(*) from realtime.messages) = n0;
end $$;
rollback;

-- 되돌린 뒤에는 다시 신호가 간다.
do $$
declare
  a  uuid := t.id('a');
  la uuid := t.id('la');
  n0 bigint;
begin
  select count(*) into n0 from realtime.messages;
  perform t.login(a);
  perform t.push1(la, t.up('accounts', gen_random_uuid(), 0, now(), t.acc('다시 신호')));
  perform t.logout();
  assert (select count(*) from realtime.messages) = n0 + 1;
end $$;
