-- 00_supabase_stub.sql
-- 로컬 시험 전용 스텁. Supabase가 미리 만들어 두는 것 가운데 이 프로젝트가 기대는 부분만 흉내 낸다.
-- 운영 DB에는 적용하지 않는다. run_local.sh가 클러스터의 슈퍼유저(supabase_admin)로 실행한다.
--
-- 흉내 내는 것
--  * 역할
--      anon, authenticated      API 요청이 쓰는 역할
--      service_role             서비스 키. RLS를 건너뛴다
--      postgres                 마이그레이션과 SQL 편집기가 쓰는 역할. Supabase에서는 슈퍼유저가 아니다
--      supabase_auth_admin      auth.users의 주인. 가입할 때 이 역할이 행을 넣는다(GoTrue)
--      supabase_realtime_admin  realtime.messages의 주인
--  * auth 스키마: auth.users(최소 컬럼), auth.uid()
--  * public 스키마의 기본 권한: postgres가 만든 테이블 · 함수 · 시퀀스는 anon · authenticated ·
--    service_role에게 전부 열린다. 그래서 마이그레이션이 권한을 직접 걷어 내야 한다
--  * realtime 스키마: realtime.messages, realtime.topic(), realtime.send()
--    psql -v with_realtime=0으로 적용하면 이 스키마를 만들지 않는다(Realtime이 없는 PostgreSQL).
--
-- 실제 Supabase와 같다고 보장하지는 않는다. 역할과 권한은 Supabase의 공개 초기화 스크립트를 따라
-- 적었지만, 실제 프로젝트와 대조해 확인한 것은 아니다.

\if :{?with_realtime}
\else
  \set with_realtime 1
\endif

-- ---------------------------------------------------------------------------
-- 역할
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'postgres') then
    create role postgres login createdb createrole replication bypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    create role supabase_auth_admin nologin noinherit createrole;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'supabase_realtime_admin') then
    create role supabase_realtime_admin nologin noinherit;
  end if;
end $$;

-- postgres는 API 역할로 바꿔 볼 수 있다(set role). 시험이 사용자를 가장할 때 쓴다.
grant anon, authenticated, service_role to postgres;
-- realtime.messages에 정책을 만들 수 있게 한다.
grant supabase_realtime_admin to postgres;
-- 시험 편의: 가입을 GoTrue의 역할로 흉내 내려고 set role만 허용한다. 권한은 물려받지 않는다.
grant supabase_auth_admin to postgres with inherit false, set true;

-- ---------------------------------------------------------------------------
-- auth
-- ---------------------------------------------------------------------------
create schema if not exists auth;

create table auth.users (
  id    uuid primary key,
  email text
);
alter table auth.users enable row level security;
alter table auth.users owner to supabase_auth_admin;

-- Supabase의 auth.uid()와 같은 정의다. PostgREST가 요청마다 JWT 클레임을 설정값으로 넣어 준다.
create function auth.uid() returns uuid
language sql stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
alter function auth.uid() owner to supabase_auth_admin;

grant usage on schema auth to anon, authenticated, service_role, postgres;
grant all on schema auth to supabase_auth_admin;
-- postgres는 auth 테이블에 FK · 트리거를 걸고 행을 지울 수 있다(스키마에 객체를 만들 수는 없다).
grant all on all tables in schema auth to postgres;

-- ---------------------------------------------------------------------------
-- public: 스키마 사용 권한과 기본 권한
-- ---------------------------------------------------------------------------
-- postgres는 데이터베이스의 주인이 아니지만 스키마와 public의 객체를 만들 수 있다.
do $$
begin
  execute format('grant all on database %I to postgres', current_database());
end $$;
grant all on schema public to postgres;
grant usage on schema public to anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on functions to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public
  grant all on sequences to postgres, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- realtime: 브로드캐스트. 실제로는 Realtime 서버가 realtime.messages의 변경을 읽어 채널로 내보낸다.
-- ---------------------------------------------------------------------------
\if :with_realtime

create schema if not exists realtime;
grant usage on schema realtime to postgres, anon, authenticated, service_role;
grant all on schema realtime to supabase_realtime_admin;

create table realtime.messages (
  id          uuid not null default gen_random_uuid(),
  topic       text not null,
  extension   text not null,
  payload     jsonb,
  event       text,
  private     boolean default false,
  updated_at  timestamp not null default now(),
  inserted_at timestamp not null default now(),
  primary key (id, inserted_at)
);
alter table realtime.messages enable row level security;
alter table realtime.messages owner to supabase_realtime_admin;
grant select, insert, update on realtime.messages to postgres, anon, authenticated, service_role;

-- 비공개 채널에 들어올 때 Realtime 서버가 주제를 이 설정값에 넣고 realtime.messages의 정책을 평가한다.
create function realtime.topic() returns text
language sql stable
as $$
  select nullif(current_setting('realtime.topic', true), '')::text
$$;
alter function realtime.topic() owner to supabase_realtime_admin;

create function realtime.send(payload jsonb, event text, topic text, private boolean default true)
returns void
language plpgsql
as $$
begin
  begin
    execute format('set local realtime.topic to %L', topic);
    insert into realtime.messages (payload, event, topic, private, extension)
    values (payload, event, topic, private, 'broadcast');
  exception when others then
    raise warning 'ErrorSendingBroadcastMessage: %', sqlerrm;
  end;
end;
$$;
alter function realtime.send(jsonb, text, text, boolean) owner to supabase_realtime_admin;

\endif
