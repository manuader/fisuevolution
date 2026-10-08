#!/usr/bin/env bash
# El oráculo del backend del ranking: un Postgres descartable con los roles de Supabase,
# las migraciones, los tests SQL y deno test. No toca ninguna base existente.
#   supabase/test.sh          todo
#   supabase/test.sh --sql    sólo los tests SQL
#   supabase/test.sh --deno   sólo deno (la integración se saltea sin DATABASE_URL)
set -euo pipefail

# Sin un locale válido el postmaster de macOS aborta ("became multithreaded during startup").
export LC_ALL=C
# Sin colores: el resumen de deno se lee con grep.
export NO_COLOR=1

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

MODE=all
case "${1:-}" in
  "") ;;
  --sql) MODE=sql ;;
  --deno) MODE=deno ;;
  *) echo "uso: supabase/test.sh [--sql|--deno]" >&2; exit 64 ;;
esac

LOG_DIR="$ROOT/build/backend"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$(date +%Y%m%d-%H%M%S)-$$.log"
exec > >(tee -a "$LOG") 2>&1

DENO_TESTS="$( (find "$HERE/functions" -name '*_test.ts' 2>/dev/null || true) | wc -l | tr -d ' ')"
DENO=()
DENO_DB_HOST=127.0.0.1

find_deno() {
  if command -v deno >/dev/null 2>&1; then
    DENO=(deno)
  elif [ -x /usr/local/bin/docker ] && /usr/local/bin/docker info >/dev/null 2>&1; then
    DENO=(/usr/local/bin/docker run --rm -e DATABASE_URL -e NO_COLOR -v "$ROOT":/w -w /w denoland/deno:2.5.0)
    DENO_DB_HOST=host.docker.internal
  else
    echo "instalar deno: \`brew install deno\`" >&2
    exit 2
  fi
}

run_deno() {
  if [ "$DENO_TESTS" = 0 ]; then
    if [ "$MODE" = deno ]; then
      echo "deno: no hay ningún *_test.ts en supabase/functions/: nada probado" >&2
      exit 1
    fi
    echo "deno: 0 archivos de test en supabase/functions/, salteado"
    return
  fi
  local out
  out="$(mktemp)"
  local status
  set +e
  "${DENO[@]}" test --config supabase/deno.json --allow-env \
    --allow-net="$DENO_DB_HOST" --allow-read supabase/functions/ 2>&1 | tee "$out"
  status=${PIPESTATUS[0]}
  set -e
  DENO_SUMMARY="$(grep -E '^(ok|FAILED) \|' "$out" | tail -1 || true)"
  rm -f "$out"
  [ "$status" = 0 ] || { echo "deno: ROJO"; exit 1; }
}

if [ "$MODE" != sql ] && [ "$DENO_TESTS" != 0 ]; then
  find_deno
fi
cd "$ROOT"

if [ "$MODE" = deno ]; then
  run_deno
  echo "deno: ${DENO_SUMMARY:-sin resumen}"
  exit 0
fi

PG_BIN=""
for v in 17 16 15; do
  if [ -x "/opt/homebrew/opt/postgresql@$v/bin/postgres" ]; then
    PG_BIN="/opt/homebrew/opt/postgresql@$v/bin"
    break
  fi
done
if [ -z "$PG_BIN" ]; then
  echo "falta Postgres 15+ de Homebrew (postgresql@16)" >&2
  exit 2
fi

PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
DATA="$ROOT/build/pg-e12-$$.noindex"
SOCK="$(mktemp -d /tmp/pge12.XXXXXX)"

cleanup() {
  "$PG_BIN/pg_ctl" -D "$DATA" -m immediate stop >/dev/null 2>&1 || true
  rm -rf "$DATA" "$SOCK"
}
trap cleanup EXIT INT TERM

"$PG_BIN/initdb" -D "$DATA" -U postgres --auth=trust -E UTF8 --locale=C >/dev/null
"$PG_BIN/pg_ctl" -D "$DATA" -l "$DATA/server.log" -w \
  -o "-p $PORT -k $SOCK -c listen_addresses=127.0.0.1 -c fsync=off" start >/dev/null
echo "postgres: $("$PG_BIN/postgres" --version | awk '{print $3}') en 127.0.0.1:$PORT"

PSQL=("$PG_BIN/psql" -X -q -v ON_ERROR_STOP=1 -h 127.0.0.1 -p "$PORT" -U postgres -d postgres)

"${PSQL[@]}" -f "$HERE/tests/pg_roles.sql"

for migration in "$HERE"/migrations/*.sql; do
  [ -e "$migration" ] || continue
  first_line="$(head -1 "$migration")"
  if [[ "$first_line" =~ ^--\ requires:\ ([a-z_]+) ]]; then
    ext="${BASH_REMATCH[1]}"
    available="$("${PSQL[@]}" -tAc "select count(*) from pg_available_extensions where name = '$ext'")"
    if [ "$available" = 0 ]; then
      echo "migración $(basename "$migration"): salteada en local (falta $ext)"
      continue
    fi
  fi
  "${PSQL[@]}" -f "$migration"
  echo "migración $(basename "$migration"): aplicada"
done

SQL_OK=0
for test_file in "$HERE"/tests/sql/*.sql; do
  [ -e "$test_file" ] || continue
  out="$(mktemp)"
  if ! "${PSQL[@]}" -f "$test_file" >"$out" 2>&1; then
    cat "$out"
    rm -f "$out"
    echo "sql: ROJO en $(basename "$test_file")"
    exit 1
  fi
  count="$(grep -c 'NOTICE:  OK ' "$out" || true)"
  sed -n 's/.*NOTICE:  OK /  OK /p' "$out"
  rm -f "$out"
  if [ "$count" = 0 ]; then
    echo "sql: $(basename "$test_file") no corrió ningún caso"
    exit 1
  fi
  echo "sql: $(basename "$test_file") — $count casos"
  SQL_OK=$((SQL_OK + count))
done
if [ "$SQL_OK" = 0 ]; then
  echo "sql: no hay tests en supabase/tests/sql/"
  exit 1
fi

if [ "$MODE" = all ]; then
  export DATABASE_URL="postgres://postgres@$DENO_DB_HOST:$PORT/postgres"
  run_deno
fi

echo "---"
echo "sql: $SQL_OK casos OK"
[ "$MODE" = all ] && echo "deno: ${DENO_SUMMARY:-sin tests}"
echo "VERDE (log: ${LOG#"$ROOT"/})"
