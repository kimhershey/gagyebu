-- 80_concurrency.sql
-- 같은 가계부에 여러 세션이 동시에 push한다. 가계부 안에서 server_seq 순서 = 커밋 순서여야 하고,
-- 커서(마지막으로 받은 server_seq)를 따라가는 기기는 어떤 행도 건너뛰지 않아야 한다.
--
-- 위험한 순서는 이렇다: 세션 A가 번호 10을 받고 아직 커밋하지 않았는데, 세션 B가 번호 11을 받아 먼저
-- 커밋한다. 그 사이에 pull한 기기는 11까지 받았다고 기억하고, 나중에 커밋된 10을 영영 받지 못한다.
-- sync_push는 가계부 단위 잠금을 커밋할 때까지 쥐어서 이 순서가 생기지 않게 한다.
--
-- 다른 세션은 보조 psql을 백그라운드로 띄워 만든다(\!). 접속 정보는 run_local.sh가 정한 환경 변수
-- (PGHOST · PGPORT · PGDATABASE · PGUSER · PSQL)를 물려받는다. \! 줄에는 psql 변수를 쓸 수 없어서
-- 보조 세션이 쓸 값은 표(t.cc_ctx)에 넣어 둔다.
\ir _helpers.sql

drop table if exists t.cc_ctx, t.cc_result, t.cc_pulled, t.cc_done;
create table t.cc_ctx    (k text primary key, v uuid not null);          -- 보조 세션에 넘길 값
create table t.cc_result (label text primary key, result jsonb not null); -- 보조 세션의 push 결과
create table t.cc_pulled (n bigserial primary key, tbl text, id uuid, version integer, server_seq bigint);
create table t.cc_done   (label text primary key);                       -- 끝난 보조 세션

create or replace function t.cc(p_key text) returns uuid
language sql stable as $$
  select v from t.cc_ctx where k = p_key
$$;

-- 조건이 참이 될 때까지 기다린다. 끝내 안 되면 실패한다.
create or replace function t.cc_wait(p_what text, p_sql text, p_timeout interval default '30 seconds')
returns void language plpgsql as $$
declare
  v_ok       boolean;
  v_deadline timestamptz := clock_timestamp() + p_timeout;
begin
  loop
    perform pg_stat_clear_snapshot();  -- pg_stat_activity는 트랜잭션 안에서 한 번 읽으면 굳는다
    execute p_sql into v_ok;
    exit when v_ok;
    if clock_timestamp() > v_deadline then
      raise exception '기다리다 시간이 다 됐다: %', p_what;
    end if;
    perform pg_sleep(0.02);
  end loop;
end $$;

-- 보조 세션(application_name)이 권고 잠금을 기다리는 중인가. p_objid를 주면 그 잠금인지도 본다.
create or replace function t.cc_waiting(p_app text, p_objid bigint default null) returns boolean
language sql as $$
  select exists (
    select 1
      from pg_locks l
      join pg_stat_activity a on a.pid = l.pid
     where a.application_name = p_app and l.locktype = 'advisory' and not l.granted
       and (p_objid is null or l.objid::bigint = p_objid))
$$;

-- 보조 세션이 부른다: 사용자의 토큰을 세션에 걸고 거래 하나를 push한다. 결과는 t.cc_result에 남긴다.
create or replace function t.cc_push(p_label text, p_batch uuid default gen_random_uuid()) returns void
language plpgsql as $$
declare
  r jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', t.cc('user'))::text, false);
  r := public.sync_push(t.cc('ledger'), gen_random_uuid(), p_batch, jsonb_build_array(
         t.up('transactions', gen_random_uuid(), 0, clock_timestamp(), t.tx(t.cc('account'), p_label))));
  insert into t.cc_result (label, result) values (p_label, r);
end $$;

-- 보조 세션이 부른다: 출발 신호(8800002)를 기다렸다가 p_rounds번 push한다. 묶음마다 트랜잭션 하나다.
-- 묶음 하나는 새 자산과 그 자산을 가리키는 거래다(두 테이블에 걸친다. 자산이 더 작은 번호를 받는다).
-- 번호를 받은 뒤 커밋을 조금 늦춘다. 가계부 잠금이 없다면 여기서 커밋 순서가 번호 순서와 어긋난다.
create or replace procedure t.cc_pusher(p_label text, p_rounds integer)
language plpgsql as $$
declare
  i   integer;
  acc uuid;
  r   jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', t.cc('user'))::text, false);
  perform pg_advisory_lock_shared(8800002);
  perform pg_advisory_unlock_shared(8800002);
  commit;
  for i in 1..p_rounds loop
    acc := gen_random_uuid();
    r := public.sync_push(t.cc('ledger'), gen_random_uuid(), gen_random_uuid(), jsonb_build_array(
           t.up('transactions', gen_random_uuid(), 0, clock_timestamp(), t.tx(acc, p_label || '-' || i)),
           t.up('accounts', acc, 0, clock_timestamp(), jsonb_build_object('name', p_label || '-' || i, 'kind', 'bank'))));
    if r -> 'results' -> 0 ->> 'status' <> 'applied' or r -> 'results' -> 1 ->> 'status' <> 'applied' then
      raise exception 'cc_pusher %: %', p_label, r;
    end if;
    perform pg_sleep(random() * 0.01);
    commit;
  end loop;
  insert into t.cc_done values (p_label);
  commit;
end $$;

-- 보조 세션이 부른다: 기기처럼 커서를 따라 pull을 되풀이하고 받은 행을 t.cc_pulled에 차례로 적는다.
-- push하는 세션이 모두 끝난 것을 본 뒤에 한 번 더 끝까지 받고 멈춘다.
create or replace procedure t.cc_puller(p_pushers integer, p_page integer)
language plpgsql as $$
declare
  v_cur      bigint := 0;
  v_done     boolean;
  r          jsonb;
  v_deadline timestamptz := clock_timestamp() + interval '90 seconds';
begin
  perform set_config('request.jwt.claims', json_build_object('sub', t.cc('user'))::text, false);
  loop
    select count(*) >= p_pushers into v_done from t.cc_done;
    loop
      r := public.sync_pull(t.cc('ledger'), v_cur, p_page);
      insert into t.cc_pulled (tbl, id, version, server_seq)
      select e.c ->> 'table', (e.c -> 'row' ->> 'id')::uuid, (e.c -> 'row' ->> 'version')::integer,
             (e.c -> 'row' ->> 'server_seq')::bigint
        from jsonb_array_elements(r -> 'changes') with ordinality as e (c, ord)
       order by e.ord;
      v_cur := (r ->> 'next_seq')::bigint;
      exit when not (r ->> 'has_more')::boolean;
    end loop;
    exit when v_done;
    if clock_timestamp() > v_deadline then
      raise exception 'cc_puller: 시간이 다 됐다';
    end if;
    perform pg_sleep(0.002);
  end loop;
  insert into t.cc_done values ('puller');
end $$;

-- ---------------------------------------------------------------------------
-- 전제: 번호는 시퀀스 하나에서 한 번에 하나씩 받는다. cache가 1보다 크면 세션마다 번호를 미리 떼어 가서
-- 나중에 받은 번호가 더 작을 수 있고, 그러면 잠금이 있어도 번호 순서가 커밋 순서와 어긋난다.
-- ---------------------------------------------------------------------------
do $$
begin
  assert (select seqcache = 1 and not seqcycle and seqincrement = 1
            from pg_sequence where seqrelid = 'public.server_seq'::regclass),
    'public.server_seq는 cache 1, increment 1, no cycle이어야 한다';
end $$;

-- ---------------------------------------------------------------------------
-- 준비
-- ---------------------------------------------------------------------------
do $$
declare
  u   uuid := t.signup();
  l   uuid := t.ledger_of(u);
  acc uuid := gen_random_uuid();
begin
  insert into t.cc_ctx values ('user', u), ('ledger', l), ('account', acc);
  perform t.login(u);
  assert t.push1(l, t.up('accounts', acc, 0, now(), '{"name": "통장", "kind": "bank"}')) ->> 'status' = 'applied';
end $$;

-- ===========================================================================
-- 1. 정해진 순서로 겹치기: A가 push하고 커밋하지 않은 동안 B가 push한다.
-- ===========================================================================
-- 운전자(이 세션)가 관문 잠금을 쥔다. A는 push한 뒤 커밋 직전에 이 잠금 앞에서 멈춘다.
do $$ begin perform pg_advisory_lock(8800001); end $$;

\! PGAPPNAME=cc_a PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "begin" -c "select t.cc_push('A')" -c "select pg_advisory_lock(8800001)" -c "commit" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &

do $$
begin
  perform t.cc_wait('세션 A가 push를 마치고 관문에서 기다린다', 'select t.cc_waiting(''cc_a'', 8800001)');
  -- A는 번호를 받았지만 커밋하지 않았다.
  perform t.set('seq_mid', t.seq()::text);
  assert (select count(*) from public.transactions where ledger_id = t.cc('ledger')) = 0, 'A의 행은 아직 안 보인다';
end $$;

\! PGAPPNAME=cc_b PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "select t.cc_push('B')" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &

do $$
declare
  l uuid := t.cc('ledger');
  r jsonb;
begin
  perform t.cc_wait('세션 B가 가계부 잠금을 기다린다', 'select t.cc_waiting(''cc_b'')');

  -- B가 기다리는 잠금은 A가 쥐고 있는 바로 그 잠금이다.
  assert (select count(*)
            from pg_locks w
            join pg_stat_activity wa on wa.pid = w.pid and wa.application_name = 'cc_b'
            join pg_locks h on h.locktype = 'advisory' and h.granted
                           and h.classid = w.classid and h.objid = w.objid and h.objsubid = w.objsubid
            join pg_stat_activity ha on ha.pid = h.pid and ha.application_name = 'cc_a'
           where w.locktype = 'advisory' and not w.granted) = 1, 'B는 A가 쥔 가계부 잠금을 기다려야 한다';

  -- B는 잠금을 얻기 전이라 번호를 받지 못했다.
  assert t.seq() = t.get('seq_mid')::bigint, format('B가 잠금 없이 번호를 받았다: %s → %s', t.get('seq_mid'), t.seq());

  -- 이때 pull하는 기기는 A의 행도 B의 행도 받지 않는다. 커서는 그 앞에 머문다.
  perform t.login(t.cc('user'));
  r := t.pull_all(l);
  assert (select count(*) from jsonb_array_elements(r -> 'changes') e where e ->> 'table' = 'transactions') = 0,
    '커밋되지 않은 행이 pull에 보인다';
  assert (r ->> 'next_seq')::bigint < t.get('seq_mid')::bigint, '커서는 A의 번호보다 앞에 있다';
  perform t.set('cursor_mid', r ->> 'next_seq');
end $$;

-- 관문을 연다. A가 커밋하고, 그 뒤에야 B가 진행한다.
do $$ begin assert pg_advisory_unlock(8800001), '관문 잠금을 쥐고 있지 않았다'; end $$;

do $$
declare
  l   uuid := t.cc('ledger');
  ra  jsonb;
  rb  jsonb;
  sa  bigint;
  sb  bigint;
  ca  timestamptz;
  cb  timestamptz;
  r   jsonb;
begin
  perform t.cc_wait('A와 B가 모두 끝난다', 'select count(*) = 2 from t.cc_result where label in (''A'', ''B'')');
  select result into ra from t.cc_result where label = 'A';
  select result into rb from t.cc_result where label = 'B';
  assert ra -> 'results' -> 0 ->> 'status' = 'applied' and rb -> 'results' -> 0 ->> 'status' = 'applied',
    format('둘 다 적용돼야 한다: %s / %s', ra, rb);
  sa := (ra ->> 'max_server_seq')::bigint;
  sb := (rb ->> 'max_server_seq')::bigint;

  -- 번호 순서 = 커밋 순서
  assert sa <= t.get('seq_mid')::bigint and sb > t.get('seq_mid')::bigint and sa < sb,
    format('A의 번호(%s)가 B의 번호(%s)보다 작아야 한다', sa, sb);
  if current_setting('track_commit_timestamp') = 'on' then
    select pg_xact_commit_timestamp(x.xmin) into ca from public.transactions x where x.ledger_id = l and x.memo = 'A';
    select pg_xact_commit_timestamp(x.xmin) into cb from public.transactions x where x.ledger_id = l and x.memo = 'B';
    assert ca is not null and cb is not null and ca <= cb, format('A가 먼저 커밋돼야 한다: %s / %s', ca, cb);
    -- B의 트랜잭션은 A가 커밋하기 전에 시작됐다. 정말로 겹쳐 있었다.
    assert (rb ->> 'server_time')::timestamptz < ca,
      format('B는 A의 커밋 전에 시작됐어야 한다: B 시작 %s, A 커밋 %s', rb ->> 'server_time', ca);
  else
    raise warning 'track_commit_timestamp가 꺼져 있어 커밋 시각은 확인하지 않는다';
  end if;

  -- 아까의 커서에서 이어 받으면 A, B가 차례로 온다. 건너뛴 행이 없다.
  perform t.login(t.cc('user'));
  r := public.sync_pull(l, t.get('cursor_mid')::bigint);
  assert jsonb_array_length(r -> 'changes') = 2
     and r -> 'changes' -> 0 -> 'row' ->> 'memo' = 'A' and r -> 'changes' -> 1 -> 'row' ->> 'memo' = 'B',
    format('커서 뒤로 A, B가 차례로 와야 한다: %s', r);
end $$;

-- ===========================================================================
-- 2. 같은 묶음을 두 세션이 동시에 보낸다(응답을 못 받은 기기의 성급한 재시도).
--    둘째는 첫째가 끝나기를 기다렸다가 저장된 결과를 받는다. 두 번 적용되지 않는다.
-- ===========================================================================
do $$ begin perform pg_advisory_lock(8800001); end $$;

\! PGAPPNAME=cc_a2 PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "begin" -c "select t.cc_push('A2', '99999999-9999-4999-8999-999999999999')" -c "select pg_advisory_lock(8800001)" -c "commit" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &

do $$ begin perform t.cc_wait('세션 A2가 관문에서 기다린다', 'select t.cc_waiting(''cc_a2'', 8800001)'); end $$;

\! PGAPPNAME=cc_b2 PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "select t.cc_push('B2', '99999999-9999-4999-8999-999999999999')" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &

do $$ begin perform t.cc_wait('세션 B2가 가계부 잠금을 기다린다', 'select t.cc_waiting(''cc_b2'')'); end $$;

do $$ begin assert pg_advisory_unlock(8800001), '관문 잠금을 쥐고 있지 않았다'; end $$;

do $$
declare
  l  uuid := t.cc('ledger');
  ra jsonb;
  rb jsonb;
begin
  perform t.cc_wait('A2와 B2가 모두 끝난다', 'select count(*) = 2 from t.cc_result where label in (''A2'', ''B2'')');
  select result into ra from t.cc_result where label = 'A2';
  select result into rb from t.cc_result where label = 'B2';
  assert ra = rb, format('같은 묶음의 두 응답이 다르다: %s / %s', ra, rb);
  assert (select count(*) from public.transactions where ledger_id = l and memo in ('A2', 'B2')) = 1
     and (select count(*) from public.transactions where ledger_id = l and memo = 'A2') = 1,
    '묶음은 한 번만 적용돼야 한다(먼저 온 A2의 내용)';
  assert (select count(*) from public.sync_batches
           where ledger_id = l and batch_id = '99999999-9999-4999-8999-999999999999') = 1;
end $$;

-- ===========================================================================
-- 3. 마구 겹치기: 네 세션이 동시에 15묶음씩 push하고, 그동안 한 세션이 7건씩 pull을 되풀이한다.
--    잠금이 없으면 pull 세션이 수십 행을 건너뛰고, pull이 테이블을 따로따로 읽어도 건너뛴다.
-- ===========================================================================
do $$ begin perform pg_advisory_lock(8800002); end $$;

\! PGAPPNAME=cc_puller PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "call t.cc_puller(4, 7)" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &
\! PGAPPNAME=cc_p1 PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "call t.cc_pusher('p1', 15)" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &
\! PGAPPNAME=cc_p2 PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "call t.cc_pusher('p2', 15)" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &
\! PGAPPNAME=cc_p3 PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "call t.cc_pusher('p3', 15)" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &
\! PGAPPNAME=cc_p4 PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "call t.cc_pusher('p4', 15)" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &

-- 네 세션이 모두 출발선에 서면 한꺼번에 내보낸다.
do $$
begin
  perform t.cc_wait('push 세션 넷이 출발 신호를 기다린다',
    'select t.cc_waiting(''cc_p1'', 8800002) and t.cc_waiting(''cc_p2'', 8800002)
        and t.cc_waiting(''cc_p3'', 8800002) and t.cc_waiting(''cc_p4'', 8800002)');
end $$;

do $$ begin assert pg_advisory_unlock(8800002), '출발 잠금을 쥐고 있지 않았다'; end $$;

do $$
declare
  l    uuid := t.cc('ledger');
  tbl  text;
  n    bigint;
  miss bigint := 0;
begin
  perform t.cc_wait('push 세션 넷과 pull 세션이 모두 끝난다', 'select count(*) = 5 from t.cc_done', interval '90 seconds');

  -- 4 × 15묶음이 모두 들어왔다(묶음마다 자산 하나, 거래 하나).
  select count(*) into n from public.transactions where ledger_id = l and memo ~ '^p[1-4]-';
  assert n = 60, format('거래 60건이어야 한다: %s', n);
  select count(*) into n from public.accounts where ledger_id = l and name ~ '^p[1-4]-';
  assert n = 60, format('자산 60개여야 한다: %s', n);

  -- (가) pull 세션은 번호가 커지는 순서로만 받았다.
  select count(*) into n
    from (select server_seq, lag(server_seq) over (order by p.n) as prev from t.cc_pulled p) q
   where prev is not null and server_seq <= prev;
  assert n = 0, format('pull한 순서가 번호 순서와 다르다(%s곳)', n);

  -- (나) 가계부의 모든 행이, 지금의 버전 · 번호 그대로, pull 세션이 받은 것 안에 있다. 건너뛴 행이 없다.
  foreach tbl in array array['profiles', 'accounts', 'categories', 'transactions', 'budgets', 'recurring_rules',
                             'category_rules', 'monthly_summaries'] loop
    execute format(
      'select count(*) from public.%I x
        where x.ledger_id = $1
          and not exists (select 1 from t.cc_pulled p
                           where p.tbl = %L and p.id = x.id and p.version = x.version and p.server_seq = x.server_seq)',
      tbl, tbl) into n using l;
    miss := miss + n;
  end loop;
  assert miss = 0, format('pull 세션이 %s행을 건너뛰었다', miss);
  assert (select count(*) from t.cc_pulled p where p.tbl = 'ledgers' and p.id = l) = 1, '가계부 행도 받았다';
  -- 고쳐진 행이 없으니 한 번씩만 받는다: 거래는 A, B, A2와 60건, 자산은 현금 · 통장과 60개.
  assert (select count(*) from t.cc_pulled p where p.tbl = 'transactions') = 63
     and (select count(*) from t.cc_pulled p where p.tbl = 'accounts') = 62,
    format('pull 세션이 받은 수: 거래 %s, 자산 %s',
           (select count(*) from t.cc_pulled p where p.tbl = 'transactions'),
           (select count(*) from t.cc_pulled p where p.tbl = 'accounts'));

  -- (다) 번호 순서 = 커밋 순서. 두 테이블의 행을 번호 순으로 늘어놓으면 커밋 시각이 뒤로 가지 않는다.
  if current_setting('track_commit_timestamp') = 'on' then
    select count(*) into n
      from (select u.cts, lag(u.cts) over (order by u.server_seq) as prev
              from (select x.server_seq, pg_xact_commit_timestamp(x.xmin) as cts
                      from public.transactions x where x.ledger_id = l
                    union all
                    select x.server_seq, pg_xact_commit_timestamp(x.xmin)
                      from public.accounts x where x.ledger_id = l) u) q
     where prev > cts;
    assert n = 0, format('번호 순서와 커밋 순서가 %s곳에서 어긋난다', n);

    -- 세션들이 정말 겹쳐서 돌았는지: 세션마다 첫 커밋과 마지막 커밋의 구간이 서로 겹친다.
    select count(*) into n
      from (select substring(x.memo from '^p[1-4]') as who,
                   min(pg_xact_commit_timestamp(x.xmin)) as first_c, max(pg_xact_commit_timestamp(x.xmin)) as last_c
              from public.transactions x where x.ledger_id = l and x.memo ~ '^p[1-4]-' group by 1) a
      join (select substring(x.memo from '^p[1-4]') as who,
                   min(pg_xact_commit_timestamp(x.xmin)) as first_c, max(pg_xact_commit_timestamp(x.xmin)) as last_c
              from public.transactions x where x.ledger_id = l and x.memo ~ '^p[1-4]-' group by 1) b
        on a.who < b.who and a.first_c < b.last_c and b.first_c < a.last_c;
    assert n >= 1, '세션들이 겹쳐서 돌지 않았다(시험이 뜻을 잃는다)';
  end if;

  assert (select count(*) from public.sync_batches where ledger_id = l) = 1 + 2 + 1 + 60, '묶음 기록 수';
end $$;

-- ===========================================================================
-- 4. 변경의 잘못이 아닌 실패(여기서는 잠금 시간 초과)는 error로 기록하지 않는다.
--    묶음 전체가 예외로 끝나고 아무것도 남지 않아서, 같은 묶음을 다시 보내면 적용된다.
--    (error로 기록해 버리면 재전송이 그 error를 그대로 돌려받아 변경을 잃는다.)
-- ===========================================================================
do $$ begin perform pg_advisory_lock(8800001); end $$;

-- 세션 X가 자산 행을 잠근 채 멈춰 있다(정리 작업처럼 push가 아닌 누군가가 행을 쥐고 있는 상황).
\! PGAPPNAME=cc_x PGOPTIONS='-c statement_timeout=120s' "${PSQL:-psql}" -X -q -v ON_ERROR_STOP=1 -c "begin" -c "select 1 from public.accounts where id = t.cc('account') for update" -c "select pg_advisory_lock(8800001)" -c "commit" >>"${GAGYEBU_AUX_LOG:-/dev/null}" 2>&1 &

do $$ begin perform t.cc_wait('세션 X가 행을 잠그고 관문에서 기다린다', 'select t.cc_waiting(''cc_x'', 8800001)'); end $$;

-- 보낼 묶음. 되돌릴 트랜잭션 밖에서 정해 둔다(되돌리면 세션 설정값도 되돌아간다).
do $$
begin
  perform t.set('retry_batch', gen_random_uuid()::text);
  perform t.set('retry_changes', jsonb_build_array(
    t.up('accounts', gen_random_uuid(), 0, now(), '{"name": "함께 보낸 새 자산", "kind": "bank"}'),
    t.up('accounts', t.cc('account'), 1, now(), '{"name": "잠긴 행 고치기"}'))::text);
end $$;

begin;
set local lock_timeout = '300ms';
do $$
declare
  l uuid := t.cc('ledger');
begin
  perform t.login(t.cc('user'));
  assert t.sqlstate_of(format('select public.sync_push(%L, %L, %L, %L)',
                              l, t.dev(1), t.id('retry_batch'), t.get('retry_changes')))
         = '55P03', '잠금 시간 초과는 변경의 error가 아니라 묶음 전체의 예외여야 한다';
end $$;
rollback;

do $$
declare
  l uuid := t.cc('ledger');
begin
  assert (select count(*) from public.sync_batches where ledger_id = l and batch_id = t.id('retry_batch')) = 0,
    '실패한 묶음이 기록되면 안 된다';
  assert (select count(*) from public.accounts where ledger_id = l and name = '함께 보낸 새 자산') = 0,
    '묶음의 다른 변경도 남지 않는다';
  assert pg_advisory_unlock(8800001);
  perform t.cc_wait('세션 X가 끝난다',
    'select not exists (select 1 from pg_stat_activity where application_name = ''cc_x'')');
end $$;

do $$
declare
  l   uuid := t.cc('ledger');
  acc uuid := t.cc('account');
  r   jsonb;
begin
  -- 같은 묶음을 다시 보내면 이번에는 적용된다.
  perform t.login(t.cc('user'));
  r := t.push(l, t.get('retry_changes')::jsonb, t.id('retry_batch'));
  assert r -> 'results' -> 0 ->> 'status' = 'applied' and r -> 'results' -> 1 ->> 'status' = 'applied',
    format('다시 보낸 묶음은 적용돼야 한다: %s', r);
  assert t.row_of('accounts', acc) ->> 'name' = '잠긴 행 고치기';
end $$;

drop table t.cc_ctx, t.cc_result, t.cc_pulled, t.cc_done;
