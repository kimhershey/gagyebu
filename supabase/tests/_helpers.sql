-- _helpers.sql
-- 시험 공용 도우미(스키마 t). 각 시험 파일이 맨 위에서 \ir _helpers.sql로 불러온다. 여러 번 불러도 된다.
-- 이름이 숫자로 시작하지 않으므로 run_local.sh가 시험으로 돌리지 않는다.
--
-- 시험은 postgres 역할(테이블의 주인, RLS를 건너뛴다)로 돈다. 사용자의 눈으로 볼 때는 t.login()으로
-- 가장한다. t.login()은 다음 두 문장과 같고, 트랜잭션(do 블록 하나)이 끝나면 풀린다.
--     set local role authenticated;
--     select set_config('request.jwt.claims', json_build_object('sub', '<uuid>')::text, true);

set client_min_messages = warning;
create schema if not exists t;
grant usage on schema t to public;

-- 가입: auth.users에 행을 넣는다. 0004의 트리거가 가계부 · 프로필 · 분류 · 현금 자산을 만든다.
create or replace function t.signup(p_email text default null) returns uuid
language plpgsql as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email) values (v_id, coalesce(p_email, v_id::text || '@test.local'));
  return v_id;
end $$;

create or replace function t.ledger_of(p_user uuid) returns uuid
language sql stable as $$
  select l.id from public.ledgers l where l.owner_id = p_user
$$;

-- 사용자 가장과 해제
create or replace function t.login(p_user uuid) returns void
language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
                     json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
end $$;

create or replace function t.login_anon() returns void
language plpgsql as $$
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
end $$;

create or replace function t.logout() returns void
language plpgsql as $$
begin
  perform set_config('role', 'none', true);
  perform set_config('request.jwt.claims', '', true);
end $$;

-- 시험 사이에 넘길 값(세션 설정값 t.<이름>). do 블록 안에서는 psql 변수를 쓸 수 없어서 둔다.
create or replace function t.set(p_name text, p_value text) returns void
language plpgsql as $$
begin
  perform set_config('t.' || p_name, p_value, false);
end $$;

create or replace function t.get(p_name text) returns text
language sql stable as $$
  select current_setting('t.' || p_name)
$$;

create or replace function t.id(p_name text) returns uuid
language sql stable as $$
  select current_setting('t.' || p_name)::uuid
$$;

-- 기기 ID(1, 2, …)
create or replace function t.dev(p_n integer) returns uuid
language sql immutable as $$
  select ('00000000-0000-4000-8000-0000000000d' || p_n)::uuid
$$;

-- 변경 하나를 만든다.
create or replace function t.up(p_table text, p_id uuid, p_base integer, p_at timestamptz, p_data jsonb)
returns jsonb language sql stable as $$
  select jsonb_build_object('table', p_table, 'op', 'upsert', 'id', p_id, 'base_version', p_base,
                            'client_updated_at', p_at, 'data', p_data)
$$;

create or replace function t.del(p_table text, p_id uuid, p_base integer, p_at timestamptz)
returns jsonb language sql stable as $$
  select jsonb_build_object('table', p_table, 'op', 'delete', 'id', p_id, 'base_version', p_base,
                            'client_updated_at', p_at)
$$;

-- 자주 쓰는 data: 자산 하나, 지출 거래 하나
create or replace function t.acc(p_name text) returns jsonb
language sql immutable as $$
  select jsonb_build_object('name', p_name, 'kind', 'bank')
$$;

create or replace function t.tx(p_account uuid, p_memo text default null) returns jsonb
language sql immutable as $$
  select jsonb_build_object('type', 'expense', 'occurred_on', '2026-11-16', 'amount', 1000,
                            'account_id', p_account, 'memo', p_memo)
$$;

-- push. 묶음 ID를 주지 않으면 새로 만든다.
create or replace function t.push(p_ledger uuid, p_changes jsonb,
                                  p_batch uuid default gen_random_uuid(), p_device uuid default t.dev(1))
returns jsonb language sql as $$
  select public.sync_push(p_ledger, p_device, p_batch, p_changes)
$$;

-- 변경 하나를 push하고 그 결과 하나만 돌려준다.
create or replace function t.push1(p_ledger uuid, p_change jsonb, p_device uuid default t.dev(1))
returns jsonb language sql as $$
  select public.sync_push(p_ledger, p_device, gen_random_uuid(), jsonb_build_array(p_change)) -> 'results' -> 0
$$;

-- 커서를 따라 끝까지 pull한다. {changes: [...], next_seq: n, pages: k}
create or replace function t.pull_all(p_ledger uuid, p_since bigint default 0, p_page integer default 500)
returns jsonb language plpgsql as $$
declare
  v_all   jsonb := '[]';
  v_cur   bigint := p_since;
  v_res   jsonb;
  v_pages integer := 0;
begin
  loop
    v_res   := public.sync_pull(p_ledger, v_cur, p_page);
    v_all   := v_all || (v_res -> 'changes');
    v_cur   := (v_res ->> 'next_seq')::bigint;
    v_pages := v_pages + 1;
    exit when not (v_res ->> 'has_more')::boolean;
    if v_pages > 100000 then
      raise exception 't.pull_all: 끝나지 않는다';
    end if;
  end loop;
  return jsonb_build_object('changes', v_all, 'next_seq', v_cur, 'pages', v_pages);
end $$;

-- pull 결과(changes 배열)에서 행 하나를 찾는다. 없으면 null.
create or replace function t.find(p_changes jsonb, p_table text, p_id uuid) returns jsonb
language sql immutable as $$
  select c -> 'row'
    from jsonb_array_elements(p_changes) as c
   where c ->> 'table' = p_table and c -> 'row' ->> 'id' = p_id::text
   limit 1
$$;

-- 테이블의 행 하나를 지금 역할의 눈으로 읽는다(RLS가 걸리면 안 보이는 행은 null).
create or replace function t.row_of(p_table text, p_id uuid) returns jsonb
language plpgsql as $$
declare
  v jsonb;
begin
  execute format('select to_jsonb(x) from public.%I as x where x.id = $1', p_table) into v using p_id;
  return v;
end $$;

-- SQL을 실행해 SQLSTATE를 돌려준다. 성공하면 '00000'. 실패하면 그 문장이 한 일은 되돌려진다.
create or replace function t.sqlstate_of(p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return '00000';
exception when others then
  return sqlstate;
end $$;

-- 같은 방식으로 오류 메시지를 돌려준다. 성공하면 null.
create or replace function t.errmsg_of(p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;

-- server_seq 시퀀스가 지금까지 내준 마지막 값. 사용자로 가장한 중에도 읽을 수 있게 definer로 둔다.
create or replace function t.seq() returns bigint
language sql security definer set search_path = pg_catalog, pg_temp as $$
  select last_value from public.server_seq
$$;

reset client_min_messages;
