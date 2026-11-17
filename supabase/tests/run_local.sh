#!/usr/bin/env bash
# run_local.sh — 임시 PostgreSQL 16 클러스터에서 스텁 → 마이그레이션 → 시험을 돌리고 지운다.
#
#   supabase/tests/run_local.sh              전체 실행
#   supabase/tests/run_local.sh -v           psql 출력을 모두 보여 준다
#   supabase/tests/run_local.sh --keep       끝나도 클러스터를 지우지 않고 접속 방법을 알려 준다
#   supabase/tests/run_local.sh 50_x.sql …   고른 시험 파일만 돌린다
#
# 환경 변수
#   PGBIN            PostgreSQL 16 실행 파일 디렉터리(기본: 자동으로 찾는다)
#   GAGYEBU_PG_PORT  임시 클러스터의 포트(기본 54329). TCP는 열지 않고 임시 디렉터리의 유닉스 소켓만 쓴다
#   GAGYEBU_PG_USER  root로 실행할 때 서버를 띄울 OS 사용자(기본 postgres). PostgreSQL은 root로 뜨지 않는다
#   GAGYEBU_TEST_TIMEOUT  시험 파일 하나의 제한 시간(초, 기본 300)
#
# 어느 디렉터리에서 실행해도 된다. 끝나면 클러스터를 멈추고 임시 디렉터리를 지운다.
# 스텁 · 마이그레이션 · 시험 가운데 하나라도 실패하면 0이 아닌 값으로 끝난다.
#
# 순서
#   1. Supabase를 흉내 낸 DB: 스텁 → 마이그레이션(번호 순) → tests/[0-9][0-9]_*.sql(스텁 제외, 번호 순)
#   2. Realtime이 없는 DB: 스텁(realtime 스키마 제외) → 마이그레이션 → push · pull 시험 하나
#      (전체 실행일 때만. realtime.send()가 없는 PostgreSQL에서도 그대로 도는지 본다.)
#
# 접속 역할
#   supabase_admin  클러스터의 슈퍼유저. 스텁만 이 역할로 적용한다
#   postgres        슈퍼유저가 아니다(Supabase와 같다). 마이그레이션과 시험은 이 역할로 돌린다

set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
MIGRATIONS="$(cd -- "$HERE/../migrations" && pwd -P)"
STUB="$HERE/00_supabase_stub.sql"
PORT="${GAGYEBU_PG_PORT:-54329}"
OS_USER="${GAGYEBU_PG_USER:-postgres}"
TEST_TIMEOUT="${GAGYEBU_TEST_TIMEOUT:-300}"
DB=gagyebu_test

die() { echo "run_local.sh: $*" >&2; exit 2; }

# --- 인자 -------------------------------------------------------------------
VERBOSE=0
KEEP=0
TESTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -v|--verbose) VERBOSE=1 ;;
    --keep)       KEEP=1 ;;
    -h|--help)    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)           die "알 수 없는 옵션: $1" ;;
    *)
      # 호출한 위치 기준 경로, 아니면 tests/ 안의 파일 이름으로 본다.
      if [ -f "$1" ]; then f="$(cd -- "$(dirname -- "$1")" && pwd -P)/$(basename -- "$1")"
      elif [ -f "$HERE/$1" ]; then f="$HERE/$1"
      else die "시험 파일이 없다: $1"
      fi
      TESTS+=("$f")
      ;;
  esac
  shift
done

# 시험 파일을 고르지 않았으면 전부 돌리고, Realtime이 없는 DB에서도 한 번 확인한다.
FULL=0
PLAIN_SMOKE="30_push_pull.sql"
if [ ${#TESTS[@]} -eq 0 ]; then
  FULL=1
  for f in "$HERE"/[0-9][0-9]_*.sql; do
    [ -e "$f" ] || continue
    [ "$f" = "$STUB" ] && continue
    TESTS+=("$f")
  done
  [ -f "$HERE/$PLAIN_SMOKE" ] || die "시험 파일이 없다: $PLAIN_SMOKE"
fi

# --- PostgreSQL 16 찾기 -----------------------------------------------------
find_pgbin() {
  local c
  for c in "${PGBIN:-}" /usr/lib/postgresql/16/bin /usr/pgsql-16/bin \
           /opt/homebrew/opt/postgresql@16/bin /usr/local/opt/postgresql@16/bin; do
    if [ -n "$c" ] && [ -x "$c/initdb" ] && [ -x "$c/pg_ctl" ] && [ -x "$c/psql" ]; then
      echo "$c"; return 0
    fi
  done
  if command -v initdb >/dev/null 2>&1 && command -v pg_ctl >/dev/null 2>&1 \
     && command -v psql >/dev/null 2>&1; then
    dirname -- "$(command -v initdb)"; return 0
  fi
  return 1
}
PGBIN="$(find_pgbin)" || die "PostgreSQL 16을 찾지 못했다. 설치하거나 PGBIN을 지정한다(예: apt-get install -y postgresql-16)."
PG_VERSION="$("$PGBIN/postgres" --version | sed 's/^postgres (PostgreSQL) //')"
case "$PG_VERSION" in
  16.*) ;;
  *) die "PostgreSQL 16이 필요하다(찾은 버전: $PG_VERSION, 위치: $PGBIN)." ;;
esac

# --- 서버를 띄울 OS 사용자 --------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
  id -u "$OS_USER" >/dev/null 2>&1 || die "OS 사용자 '$OS_USER'가 없다. GAGYEBU_PG_USER로 지정한다."
  command -v runuser >/dev/null 2>&1 || die "runuser가 없다."
  as_pg() { runuser -u "$OS_USER" -- "$@"; }
else
  as_pg() { "$@"; }
fi

# --- 임시 디렉터리와 뒷정리 -------------------------------------------------
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gagyebu-pg.XXXXXX")"
LOGS="$TMP/logs"

cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  cd /
  if [ -d "$TMP" ]; then
    if [ "$KEEP" -eq 1 ] && [ -f "$TMP/data/postmaster.pid" ]; then
      echo
      echo "클러스터를 남겨 둔다."
      echo "  접속: $PGBIN/psql -h $TMP -p $PORT -U postgres $DB"
      echo "  정리: $([ "$(id -u)" -eq 0 ] && echo "runuser -u $OS_USER -- ")$PGBIN/pg_ctl -D $TMP/data -m fast stop && rm -rf $TMP"
    else
      if [ -f "$TMP/data/postmaster.pid" ]; then
        as_pg "$PGBIN/pg_ctl" -D "$TMP/data" -m immediate -w stop >/dev/null 2>&1 || true
      fi
      rm -rf -- "$TMP"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$LOGS"

# 유닉스 소켓 경로는 길이 제한(약 107바이트)이 있다.
[ $(( ${#TMP} + 20 )) -le 107 ] || die "임시 디렉터리 경로가 너무 길다: $TMP (TMPDIR을 짧게 지정한다)"
if [ "$(id -u)" -eq 0 ]; then chown "$OS_USER" "$TMP"; fi
cd "$TMP"

# --- 클러스터 만들기 --------------------------------------------------------
echo "PostgreSQL $PG_VERSION · 임시 클러스터(유닉스 소켓, 포트 $PORT)"

as_pg "$PGBIN/initdb" -D "$TMP/data" -U supabase_admin -A trust -E UTF8 --no-locale --no-sync \
  >"$LOGS/initdb.log" 2>&1 || { cat "$LOGS/initdb.log" >&2; die "initdb 실패"; }

# fsync를 끄는 것은 버릴 클러스터라서다. track_commit_timestamp는 동시성 시험이 커밋 순서를 볼 때 쓴다.
as_pg "$PGBIN/pg_ctl" -D "$TMP/data" -l "$TMP/server.log" -w -t 60 \
  -o "-p $PORT -k '$TMP' -c listen_addresses='' -c fsync=off -c synchronous_commit=off -c full_page_writes=off -c track_commit_timestamp=on -c max_connections=40" \
  start >"$LOGS/pg_ctl.log" 2>&1 || { cat "$LOGS/pg_ctl.log" "$TMP/server.log" >&2 2>/dev/null; die "서버 시작 실패"; }

# psql은 호출한 사용자로 돌린다(파일을 읽을 수 있어야 한다). 접속은 환경 변수로 정한다.
# 시험 파일이 띄우는 보조 psql(\!)도 같은 환경 변수를 물려받는다.
unset PGSERVICE PGSERVICEFILE PGPASSWORD PGPASSFILE PGSSLMODE PGHOSTADDR PGAPPNAME PGOPTIONS
export PGHOST="$TMP" PGPORT="$PORT" PGDATABASE="$DB" PGUSER=postgres PGCONNECT_TIMEOUT=10
export PGCLIENTENCODING=UTF8
export PSQL="$PGBIN/psql"
# 보조 psql의 출력이 모이는 곳. 시험이 실패하면 함께 보여 준다.
export GAGYEBU_AUX_LOG="$LOGS/aux.log"

with_timeout() {
  if command -v timeout >/dev/null 2>&1; then timeout "$TEST_TIMEOUT" "$@"; else "$@"; fi
}

# run_sql <역할> <파일> [psql 옵션…]: 파일을 적용하고 출력은 로그에 모은다.
STEP=0
LAST_LOG=""
run_sql() {
  local role="$1" file="$2"; shift 2
  STEP=$((STEP + 1))
  LAST_LOG="$LOGS/$(printf '%02d' "$STEP")_$(basename -- "$file").log"
  local rc=0
  if [ "$VERBOSE" -eq 1 ]; then
    with_timeout "$PSQL" -X -v ON_ERROR_STOP=1 -U "$role" "$@" -f "$file" 2>&1 | tee "$LAST_LOG" || rc=$?
  else
    PGOPTIONS="-c client_min_messages=warning" \
      with_timeout "$PSQL" -X -q -v ON_ERROR_STOP=1 -U "$role" "$@" -f "$file" >"$LAST_LOG" 2>&1 || rc=$?
  fi
  return "$rc"
}

show_log() {
  if [ "$VERBOSE" -eq 0 ]; then
    sed 's/^/      | /' "$LAST_LOG" | tail -n 40
  fi
  if [ -s "$GAGYEBU_AUX_LOG" ]; then
    echo "      (보조 세션의 출력)"
    sed 's/^/      : /' "$GAGYEBU_AUX_LOG" | tail -n 20
  fi
}

# --- 스텁과 마이그레이션 ----------------------------------------------------
# prepare_db <DB> <with_realtime: 1|0>: DB를 만들고 스텁과 마이그레이션을 적용한다. 실패하면 끝낸다.
prepare_db() {
  local db="$1" with_realtime="$2" f
  "$PSQL" -X -q -v ON_ERROR_STOP=1 -U supabase_admin -d postgres \
    -c "create database $db" >"$LOGS/createdb_$db.log" 2>&1 \
    || { cat "$LOGS/createdb_$db.log" >&2; die "데이터베이스 생성 실패: $db"; }
  export PGDATABASE="$db"

  if run_sql supabase_admin "$STUB" -v with_realtime="$with_realtime"; then
    echo "ok    tests/$(basename -- "$STUB")"
  else
    echo "FAIL  tests/$(basename -- "$STUB")"; show_log
    exit 1
  fi
  for f in "$MIGRATIONS"/[0-9]*.sql; do
    # 마이그레이션 하나는 트랜잭션 하나다(Supabase CLI와 같다).
    if run_sql postgres "$f" --single-transaction; then
      echo "ok    migrations/$(basename -- "$f")"
    else
      echo "FAIL  migrations/$(basename -- "$f")"; show_log
      exit 1
    fi
  done
}

# run_test <파일>: 시험 파일 하나를 돌리고 PASS · FAIL을 적는다.
passed=0
failed=0
run_test() {
  local f="$1" rc=0
  : >"$GAGYEBU_AUX_LOG"
  run_sql postgres "$f" || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS  $(basename -- "$f")"
    passed=$((passed + 1))
  else
    if [ "$rc" -eq 124 ]; then
      echo "FAIL  $(basename -- "$f")  (제한 시간 ${TEST_TIMEOUT}초 초과)"
    else
      echo "FAIL  $(basename -- "$f")"
    fi
    show_log
    failed=$((failed + 1))
  fi
}

# --- Supabase를 흉내 낸 DB: 모든 시험 ---------------------------------------
echo "[$DB] Supabase 스텁(auth · realtime)"
prepare_db "$DB" 1
for f in "${TESTS[@]}"; do
  run_test "$f"
done

# --- Realtime이 없는 DB: 마이그레이션이 그대로 적용되고 push · pull이 되는지만 본다 ----
if [ "$FULL" -eq 1 ]; then
  echo "[${DB}_plain] Realtime이 없는 PostgreSQL(스텁에서 realtime 스키마를 뺀다)"
  prepare_db "${DB}_plain" 0
  run_test "$HERE/$PLAIN_SMOKE"
  export PGDATABASE="$DB"
fi

echo "결과: 시험 $((passed + failed))건 · 통과 $passed · 실패 $failed"
[ "$failed" -eq 0 ] && [ "$passed" -gt 0 ]
