-- 0003_sync.sql
-- 동기화 RPC. 기기는 이 두 함수로만 서버와 행을 주고받는다. 계약은 supabase/README.md에 있다.
--
--   sync_push  기기의 변경 묶음을 받아 적용한다. 서버의 쓰기는 전부 여기를 거친다.
--   sync_pull  커서(server_seq) 뒤의 변경을 순서대로 내려 준다.
--
-- 순서 보장
--  * push는 가계부 단위 잠금을 잡은 뒤에 server_seq를 받고, 잠금은 커밋할 때 풀린다.
--    그래서 한 가계부 안에서는 server_seq 순서와 커밋 순서가 같다. 기기가 "마지막으로 받은
--    server_seq"만 기억해도 그보다 작은 번호가 뒤늦게 나타나지 않는다.
--  * pull은 모든 테이블을 SQL 한 문장(스냅샷 하나)으로 읽는다. 테이블마다 따로 읽으면 그 사이에
--    커밋된 묶음의 앞부분을 건너뛸 수 있다.
--
-- 보안
--  * 둘 다 SECURITY DEFINER이고 테이블 주인의 권한으로 돈다(RLS를 건너뛴다). 그래서 함수가 직접
--    auth.uid()로 가계부의 주인인지 확인한다.
--  * search_path는 pg_catalog, pg_temp로 고정하고 그 밖의 이름에는 모두 스키마를 붙인다.
--    ''로 두면 pg_temp가 맨 앞에서 암묵적으로 검색돼, 임시 타입이 jsonb · uuid 같은 이름을 가릴 수 있다.
--  * 동적 SQL에 넣는 테이블 이름은 허용 목록에 있는 것만 %I로 넣고, 컬럼 이름은 카탈로그에서 읽는다.
--    기기가 보낸 값은 전부 매개변수($n)로 넘긴다.
--  * 시각은 UTC로 고정해 JSON으로 바꾼다(예: "2026-11-17T05:00:01.123456+00:00").
--
-- README가 정하지 않아 여기서 정한 것(까닭은 해당 줄의 주석에 적었다)
--  * data에 없는 컬럼은 새 행이면 기본값, 있던 행이면 지금 값을 그대로 둔다. 값을 비우려면 null을 보낸다.
--  * 같은 묶음에서 같은 행을 다시 고치면 보낸 순서대로 이어서 적용한다. 행 하나에 100번까지 받는다.
--  * 다른 행을 가리키는 값(FK 컬럼)은 같은 가계부의 행이어야 한다.
--  * JSON으로 적을 수 없는 날짜 · 시각 · 실수(infinity, 기원전, 다섯 자리 연도, NaN)는 받지 않는다.
--  * 변경의 잘못이 아닌 실패(교착, 잠금 시간 초과 등)는 error로 기록하지 않고 묶음 전체를 실패시킨다.
--  * 결과의 version · server_seq는 처리한 뒤 서버 행의 값이다(conflict_lost면 지금 서버 행의 값).

-- ---------------------------------------------------------------------------
-- sync_push
-- ---------------------------------------------------------------------------
create or replace function public.sync_push(
  p_ledger_id uuid,
  p_device_id uuid,
  p_batch_id  uuid,
  p_changes   jsonb
) returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, pg_temp
set timezone = 'UTC'
as $$
declare
  -- 동기화하는 테이블. 이 순서(의존 순서)로 적용한다. 동적 SQL에 들어갈 수 있는 이름의 허용 목록이기도 하다.
  c_tables constant text[] := array[
    'ledgers', 'profiles', 'accounts', 'categories', 'transactions',
    'budgets', 'recurring_rules', 'category_rules', 'monthly_summaries'];
  -- 서버가 관리하는 컬럼. data에 들어 있어도 쓰지 않는다. 생성 컬럼은 카탈로그를 보고 따로 뺀다.
  c_managed constant text[] := array[
    'id', 'ledger_id', 'version', 'server_seq', 'client_updated_at',
    'created_at', 'updated_at', 'deleted_at'];
  -- 한 묶음에서 같은 행을 고칠 수 있는 횟수. 한 트랜잭션이 같은 행을 n번 고치면 비용이 n²으로 는다.
  c_max_per_row constant integer := 100;
  -- 날짜 · 시각으로 받는 범위. 이 밖의 값(기원전, 다섯 자리 연도)과 infinity는 README의 JSON 표현으로
  -- 적히지 않아, 한 기기가 넣으면 같은 가계부의 다른 기기가 pull한 행을 읽지 못한다.
  c_min_time constant timestamptz := '0001-01-01 00:00:00+00';
  c_max_time constant timestamptz := '10000-01-01 00:00:00+00';

  v_uid        uuid := auth.uid();
  v_now        timestamptz := now();
  v_result     jsonb;
  v_meta       jsonb;           -- 테이블 → {cols, refs, kinds}. 아래에서 카탈로그를 읽어 채운다
  v_results    jsonb[];         -- p_changes와 같은 순서의 결과
  v_first_seq  bigint;          -- 이 묶음이 처음 받은 server_seq
  v_max_seq    bigint;          -- 이 묶음이 쓴 가장 큰 server_seq

  v_change     jsonb;           -- 변경 하나, 그 자리(1부터), 같은 행을 고치는 변경 가운데 몇 번째인지
  v_ord        integer;
  v_nth        integer;
  v_table      text;
  v_op         text;
  v_id         uuid;
  v_base       numeric;
  v_at         timestamptz;
  v_data       jsonb;
  v_row_ledger uuid;
  v_old        jsonb;           -- 서버의 현재 행
  v_cols       text[];          -- data에 실제로 들어 있는, 쓸 수 있는 컬럼
  v_ref        record;
  v_kind       record;
  v_ts         timestamptz;
  v_found      boolean;
  v_status     text;            -- 변경 하나의 결과
  v_version    integer;
  v_seq        bigint;
  v_server_row jsonb;
  v_error      text;
begin
  -- 1. 가계부의 주인인지 확인한다. 잠금보다 먼저 본다(남의 가계부 잠금 앞에 줄을 설 수 없게).
  if v_uid is null or not exists (
       select 1 from public.ledgers l where l.id = p_ledger_id and l.owner_id = v_uid) then
    raise exception 'not the owner of this ledger' using errcode = '42501';
  end if;

  if p_device_id is null or p_batch_id is null then
    raise exception 'p_device_id and p_batch_id are required' using errcode = '22004';
  end if;
  if p_changes is null or jsonb_typeof(p_changes) <> 'array' then
    raise exception 'p_changes must be a JSON array' using errcode = '22023';
  end if;
  -- 잠금을 얻은 뒤의 문장은 앞선 push가 커밋한 것을 봐야 한다. read committed에서만 그렇다.
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'sync_push requires READ COMMITTED isolation' using errcode = '0A000';
  end if;

  -- 2. 가계부 단위 잠금. 같은 가계부의 push는 차례로 처리되고, 잠금은 트랜잭션이 끝날 때 풀린다.
  --    (delete_my_account()도 같은 키를 쓴다. 키를 바꾸면 0004도 함께 바꾼다.)
  perform pg_advisory_xact_lock(hashtextextended('gagyebu.ledger:' || p_ledger_id::text, 0));

  -- 잠금을 기다리는 사이에 계정이 지워졌을 수 있다.
  if not exists (select 1 from public.ledgers l where l.id = p_ledger_id and l.owner_id = v_uid) then
    raise exception 'not the owner of this ledger' using errcode = '42501';
  end if;

  -- 3. 이미 처리한 묶음이면 저장해 둔 결과를 그대로 돌려준다(멱등).
  select b.result into v_result
    from public.sync_batches b
   where b.ledger_id = p_ledger_id and b.batch_id = p_batch_id;
  if found then
    return v_result;
  end if;

  -- 테이블마다 필요한 것을 카탈로그에서 한 번 읽어 둔다. 컬럼이 늘어도 이 함수는 고치지 않아도 된다.
  select jsonb_object_agg(c.relname, jsonb_build_object(
           -- cols: 기기가 쓸 수 있는 컬럼(서버가 관리하는 컬럼과 생성 컬럼을 뺀 나머지)
           'cols', (
             select coalesce(jsonb_agg(a.attname order by a.attnum), '[]'::jsonb)
               from pg_attribute a
              where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
                and a.attgenerated = '' and a.attname::text <> all (c_managed)),
           -- refs: 같은 가계부의 행을 가리켜야 하는 FK 컬럼 → 가리키는 테이블
           'refs', (
             select coalesce(jsonb_object_agg(a.attname, r.relname), '{}'::jsonb)
               from pg_constraint k
               join pg_attribute a on a.attrelid = k.conrelid and a.attnum = k.conkey[1]
               join pg_class r on r.oid = k.confrelid
              where k.conrelid = c.oid and k.contype = 'f' and cardinality(k.conkey) = 1
                and r.relnamespace = c.relnamespace
                and r.relname::text = any (c_tables) and r.relname <> 'ledgers'),
           -- kinds: 값의 범위를 확인할 컬럼 → 'time'(날짜 · 시각) 또는 'number'(실수)
           'kinds', (
             select coalesce(jsonb_object_agg(a.attname,
                      case when a.atttypid in ('date'::regtype, 'timestamp'::regtype, 'timestamptz'::regtype)
                           then 'time' else 'number' end), '{}'::jsonb)
               from pg_attribute a
              where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
                and a.attgenerated = '' and a.attname::text <> all (c_managed)
                and a.atttypid in ('date'::regtype, 'timestamp'::regtype, 'timestamptz'::regtype,
                                   'numeric'::regtype, 'float4'::regtype, 'float8'::regtype))))
    into v_meta
    from pg_class c
   where c.relnamespace = 'public'::regnamespace and c.relname::text = any (c_tables);
  -- ledgers는 이름과 통화만 고칠 수 있다(owner_id는 절대 쓰지 않는다).
  v_meta := jsonb_set(v_meta, '{ledgers,cols}', '["name", "currency"]');

  v_results := array_fill(null::jsonb, array[jsonb_array_length(p_changes)]);

  -- 4. 테이블 의존 순서로, 같은 테이블 안에서는 보낸 순서로 적용한다.
  for v_change, v_ord, v_nth in
    select e.value, e.ordinality::integer,
           row_number() over (
             partition by e.value ->> 'table',
                          -- UUID는 대소문자 · 붙임표 · 중괄호가 달라도 같은 값일 수 있다. 16진수만 남겨 묶는다.
                          lower(regexp_replace(e.value ->> 'id', '[^0-9A-Fa-f]', '', 'g'))
             order by e.ordinality)::integer
      from jsonb_array_elements(p_changes) with ordinality as e (value, ordinality)
     order by coalesce(array_position(c_tables, e.value ->> 'table'), 0), e.ordinality
  loop
    v_table := null;  v_id := null;  v_status := null;  v_version := null;
    v_seq := null;    v_server_row := null;             v_error := null;

    -- 변경 하나는 하위 트랜잭션 하나다. 실패하면 그 변경만 되돌리고 error로 답한다.
    begin
      -- 형식 확인 --------------------------------------------------------
      if jsonb_typeof(v_change) <> 'object' then
        raise exception 'change must be a JSON object' using errcode = '22023';
      end if;

      v_table := v_change ->> 'table';
      if v_table is null or v_table <> all (c_tables) then
        raise exception 'unknown table' using errcode = '22023';
      end if;

      v_op := v_change ->> 'op';
      if v_op is null or v_op not in ('upsert', 'delete') then
        raise exception 'op must be "upsert" or "delete"' using errcode = '22023';
      end if;

      v_id := (v_change ->> 'id')::uuid;
      if v_id is null then
        raise exception 'id is required' using errcode = '22023';
      end if;
      if v_nth > c_max_per_row then
        raise exception 'too many changes to the same row in one batch (limit %)', c_max_per_row
          using errcode = '54000';
      end if;

      if jsonb_typeof(v_change -> 'base_version') is distinct from 'number' then
        raise exception 'base_version must be a non-negative integer' using errcode = '22023';
      end if;
      v_base := (v_change -> 'base_version')::numeric;
      if v_base < 0 or v_base > 2147483647 or v_base <> trunc(v_base) then
        raise exception 'base_version must be a non-negative integer' using errcode = '22023';
      end if;

      v_at := (v_change ->> 'client_updated_at')::timestamptz;
      if v_at is null then
        raise exception 'client_updated_at is required' using errcode = '22023';
      end if;
      if not isfinite(v_at) or v_at < c_min_time then
        raise exception 'client_updated_at is out of range' using errcode = '22008';
      end if;
      -- 5. 서버 시각보다 앞선 시각은 서버 시각으로 자른다. 시계가 빠른 기기가 계속 이기지 못하게 한다.
      v_at := least(v_at, v_now);

      v_data := v_change -> 'data';
      if v_op = 'upsert' and jsonb_typeof(v_data) is distinct from 'object' then
        raise exception 'data must be a JSON object' using errcode = '22023';
      end if;

      -- ledgers와 profiles는 서버가 만들어 둔 자기 행만 고칠 수 있고, 지울 수 없다.
      if v_table = 'ledgers' and (v_id <> p_ledger_id or v_op = 'delete') then
        raise exception 'ledgers: only name and currency of this ledger can be changed'
          using errcode = '42501';
      end if;
      if v_table = 'profiles' and (v_id <> v_uid or v_op = 'delete') then
        raise exception 'profiles: only your own profile can be changed' using errcode = '42501';
      end if;

      -- 서버의 현재 행 --------------------------------------------------
      -- 잠그고 읽는다(for update). 다른 가계부의 행은 잠그지도 돌려주지도 않는다.
      if v_table = 'ledgers' then
        select to_jsonb(l) into v_old from public.ledgers l where l.id = v_id for update;
      else
        execute format('select t.ledger_id from public.%I as t where t.id = $1', v_table)
           into v_row_ledger using v_id;
        if v_row_ledger <> p_ledger_id then
          raise exception 'id is in use outside this ledger' using errcode = '42501';
        end if;
        execute format(
          'select to_jsonb(t) from public.%I as t where t.id = $1 and t.ledger_id = $2 for update',
          v_table)
           into v_old using v_id, p_ledger_id;
      end if;

      -- 6. 판정 ----------------------------------------------------------
      if v_old is null then
        if v_op = 'delete' then
          -- 서버에 없는 행을 지우라는 요청. 할 일이 없다.
          v_status  := 'applied';
          v_version := 0;
        elsif v_table = 'ledgers' then
          raise exception 'ledgers: cannot be created' using errcode = '42501';
        else
          v_status := 'applied';
        end if;
      elsif v_base = (v_old ->> 'version')::integer
            or (v_old ->> 'server_seq')::bigint >= v_first_seq then
        -- 둘째 조건: 이 묶음이 방금 쓴 행을 같은 묶음에서 다시 고치는 경우다. 보낸 순서대로 이어서
        -- 적용한다(기기는 앞 변경의 새 버전을 아직 모르므로 base_version이 같을 수밖에 없다).
        -- 잠금을 잡고 있는 동안 이 가계부에 새 번호를 쓰는 것은 이 묶음뿐이라, 번호만 봐도 안다.
        v_status := 'applied';
      elsif v_at > (v_old ->> 'client_updated_at')::timestamptz then
        v_status     := 'conflict_won';
        v_server_row := v_old;
      else
        v_status     := 'conflict_lost';
        v_server_row := v_old;
        v_version    := (v_old ->> 'version')::integer;
        v_seq        := (v_old ->> 'server_seq')::bigint;
      end if;

      -- 7. 쓰기 ----------------------------------------------------------
      if v_status = 'conflict_lost' or (v_old is null and v_op = 'delete') then
        null;  -- 쓰지 않는다

      elsif v_op = 'delete' then
        v_seq := nextval('public.server_seq'::regclass);
        v_first_seq := coalesce(v_first_seq, v_seq);
        execute format(
          'update public.%I as t
              set version = t.version + 1, server_seq = $2, client_updated_at = $3,
                  updated_at = $4, deleted_at = $4
            where t.id = $1
        returning t.version', v_table)
           into strict v_version using v_id, v_seq, v_at, v_now;

      else
        -- data에 들어 있는 컬럼만 쓴다. 빠진 컬럼은 새 행이면 기본값, 있던 행이면 지금 값을 그대로 둔다.
        v_cols := array(
          select c.name
            from jsonb_array_elements_text(v_meta -> v_table -> 'cols') with ordinality as c (name, ord)
           where v_data ? c.name
           order by c.ord);

        -- 다른 행을 가리키는 값은 같은 가계부의 행이어야 한다. 없는 행과 남의 가계부 행을 같은
        -- 오류로 답해, 다른 가계부에 그 ID가 있는지 알려 주지 않는다.
        for v_ref in
          select r.key as col, r.value as tbl from jsonb_each_text(v_meta -> v_table -> 'refs') as r
        loop
          if jsonb_typeof(v_data -> v_ref.col) <> 'null' then
            execute format(
              'select exists (select 1 from public.%I as p where p.id = $1 and p.ledger_id = $2)',
              v_ref.tbl)
               into v_found using (v_data ->> v_ref.col)::uuid, p_ledger_id;
            if not v_found then
              raise exception '%: no such row in this ledger', v_ref.col using errcode = '23503';
            end if;
          end if;
        end loop;

        -- 날짜 · 시각 · 실수 값은 README의 JSON 표현으로 적을 수 있어야 한다.
        for v_kind in
          select k.key as col, k.value as kind from jsonb_each_text(v_meta -> v_table -> 'kinds') as k
        loop
          if jsonb_typeof(v_data -> v_kind.col) <> 'null' then
            if v_kind.kind = 'time' then
              v_ts := (v_data ->> v_kind.col)::timestamptz;
              if not isfinite(v_ts) or v_ts < c_min_time or v_ts >= c_max_time then
                raise exception '%: date/time out of range', v_kind.col using errcode = '22008';
              end if;
            elsif (v_data ->> v_kind.col)::numeric in ('NaN', 'Infinity', '-Infinity') then
              raise exception '%: number out of range', v_kind.col using errcode = '22003';
            end if;
          end if;
        end loop;

        v_seq := nextval('public.server_seq'::regclass);
        v_first_seq := coalesce(v_first_seq, v_seq);
        if v_old is null then
          execute format(
            'insert into public.%1$I
                    (id, ledger_id, version, server_seq, client_updated_at, created_at, updated_at%2$s)
             select $1, $2, 1, $3, $4, $5, $5%3$s
               from jsonb_populate_record(null::public.%1$I, $6) as r',
            v_table,
            (select coalesce(string_agg(format(', %I', u.c), '' order by u.ord), '')
               from unnest(v_cols) with ordinality as u (c, ord)),
            (select coalesce(string_agg(format(', r.%I', u.c), '' order by u.ord), '')
               from unnest(v_cols) with ordinality as u (c, ord)))
            using v_id, p_ledger_id, v_seq, v_at, v_now, v_data;
          v_version := 1;
        else
          -- 삭제 표시가 있던 행이면 되살린다(deleted_at = null).
          execute format(
            'update public.%1$I as t
                set version = t.version + 1, server_seq = $2, client_updated_at = $3,
                    updated_at = $4, deleted_at = null%2$s
               from jsonb_populate_record(null::public.%1$I, $5) as r
              where t.id = $1
          returning t.version',
            v_table,
            (select coalesce(string_agg(format(', %1$I = r.%1$I', u.c), '' order by u.ord), '')
               from unnest(v_cols) with ordinality as u (c, ord)))
             into strict v_version using v_id, v_seq, v_at, v_now, v_data;
        end if;
      end if;

      if v_seq is not null and v_status <> 'conflict_lost' then
        v_max_seq := greatest(v_max_seq, v_seq);
      end if;

    exception when others then
      -- 일시적인 장애(읽기 전용 트랜잭션, 직렬화 실패 · 교착, 자원 부족, 잠금 시간 초과, 시스템 오류)는
      -- 이 변경의 잘못이 아니다. 묶음 전체를 실패시켜 기기가 같은 묶음을 다시 보내게 한다.
      if sqlstate like any (array['25%', '40%', '53%', '57%', '58%', 'XX%']) or sqlstate = '55P03' then
        raise;
      end if;
      v_status := 'error';  v_version := null;  v_seq := null;  v_server_row := null;
      v_error  := sqlerrm;
    end;

    v_results[v_ord] := jsonb_build_object(
      'table',      v_change ->> 'table',
      'id',         coalesce(v_id::text, v_change ->> 'id'),
      'status',     v_status,
      'version',    v_version,
      'server_seq', v_seq,
      'server_row', v_server_row,
      'error',      v_error);
  end loop;

  -- 8. 결과를 저장하고 돌려준다.
  v_result := jsonb_build_object(
    'batch_id',       p_batch_id,
    'server_time',    v_now,
    'max_server_seq', v_max_seq,
    'results',        to_jsonb(v_results));

  insert into public.sync_batches (ledger_id, batch_id, device_id, result)
  values (p_ledger_id, p_batch_id, p_device_id, v_result);

  -- 다른 기기에 변경 신호를 보낸다. realtime.send()는 Supabase에만 있으므로 있을 때만 부른다.
  -- 신호는 커밋된 뒤에 전달된다. 신호를 못 보내도 push는 성공이다(기기는 주기적으로도 pull한다).
  if v_max_seq is not null then
    begin
      if to_regprocedure('realtime.send(jsonb,text,text,boolean)') is not null then
        execute 'select realtime.send($1, $2, $3, $4)'
          using jsonb_build_object('server_seq', v_max_seq),  -- 내용: 마지막 server_seq뿐
                'changed'::text,                               -- 이벤트
                'ledger:' || p_ledger_id::text,                -- 주제
                true;                                          -- 비공개 채널(0002의 정책을 통과해야 듣는다)
      end if;
    exception when others then
      raise warning 'sync_push: realtime signal failed: %', sqlerrm;
    end;
  end if;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- sync_pull
-- ---------------------------------------------------------------------------
create or replace function public.sync_pull(
  p_ledger_id uuid,
  p_since     bigint,
  p_limit     integer default 500
) returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, pg_temp
set timezone = 'UTC'
as $$
declare
  v_uid     uuid := auth.uid();
  v_since   bigint := coalesce(p_since, 0);
  v_limit   integer := least(greatest(coalesce(p_limit, 500), 1), 2000);
  v_changes jsonb;
  v_last    bigint;
  v_count   bigint;
begin
  if v_uid is null or not exists (
       select 1 from public.ledgers l where l.id = p_ledger_id and l.owner_id = v_uid) then
    raise exception 'not the owner of this ledger' using errcode = '42501';
  end if;

  -- 모든 테이블을 한 문장으로 읽는다(스냅샷 하나). 다음 장이 있는지 보려고 한 건 더 읽는다.
  select coalesce(jsonb_agg(jsonb_build_object('table', p.tbl, 'row', p.doc) order by p.server_seq)
                    filter (where p.n <= v_limit), '[]'::jsonb),
         max(p.server_seq) filter (where p.n <= v_limit),
         count(*)
    into v_changes, v_last, v_count
    from (
      select u.tbl, u.server_seq, u.doc, row_number() over (order by u.server_seq) as n
        from (
          (select 'ledgers'::text as tbl, t.server_seq, to_jsonb(t) as doc
             from public.ledgers t
            where t.id = p_ledger_id and t.server_seq > v_since)
          union all
          (select 'profiles', t.server_seq, to_jsonb(t)
             from public.profiles t
            where t.ledger_id = p_ledger_id and t.server_seq > v_since
            order by t.server_seq limit v_limit + 1)
          union all
          (select 'accounts', t.server_seq, to_jsonb(t)
             from public.accounts t
            where t.ledger_id = p_ledger_id and t.server_seq > v_since
            order by t.server_seq limit v_limit + 1)
          union all
          (select 'categories', t.server_seq, to_jsonb(t)
             from public.categories t
            where t.ledger_id = p_ledger_id and t.server_seq > v_since
            order by t.server_seq limit v_limit + 1)
          union all
          (select 'transactions', t.server_seq, to_jsonb(t)
             from public.transactions t
            where t.ledger_id = p_ledger_id and t.server_seq > v_since
            order by t.server_seq limit v_limit + 1)
          union all
          (select 'budgets', t.server_seq, to_jsonb(t)
             from public.budgets t
            where t.ledger_id = p_ledger_id and t.server_seq > v_since
            order by t.server_seq limit v_limit + 1)
          union all
          (select 'recurring_rules', t.server_seq, to_jsonb(t)
             from public.recurring_rules t
            where t.ledger_id = p_ledger_id and t.server_seq > v_since
            order by t.server_seq limit v_limit + 1)
          union all
          (select 'category_rules', t.server_seq, to_jsonb(t)
             from public.category_rules t
            where t.ledger_id = p_ledger_id and t.server_seq > v_since
            order by t.server_seq limit v_limit + 1)
          union all
          (select 'monthly_summaries', t.server_seq, to_jsonb(t)
             from public.monthly_summaries t
            where t.ledger_id = p_ledger_id and t.server_seq > v_since
            order by t.server_seq limit v_limit + 1)
        ) u
       order by u.server_seq
       limit v_limit + 1
    ) p;

  return jsonb_build_object(
    'changes',     v_changes,
    'next_seq',    coalesce(v_last, v_since),
    'has_more',    v_count > v_limit,
    'server_time', now());
end;
$$;

-- ---------------------------------------------------------------------------
-- 실행 권한: 로그인한 사용자만
-- (Supabase는 public 스키마의 새 함수를 anon · authenticated · service_role에게 기본으로 열어 준다.)
-- ---------------------------------------------------------------------------
revoke all on function public.sync_push(uuid, uuid, uuid, jsonb) from public, anon, authenticated, service_role;
revoke all on function public.sync_pull(uuid, bigint, integer)   from public, anon, authenticated, service_role;
grant execute on function public.sync_push(uuid, uuid, uuid, jsonb) to authenticated;
grant execute on function public.sync_pull(uuid, bigint, integer)   to authenticated;
