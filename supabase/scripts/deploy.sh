#!/usr/bin/env bash
# Despliega el backend del ranking al proyecto de Supabase YA ENLAZADO (`supabase link`).
# Corre el oráculo antes. No setea secretos: los imprime como pasos para el dueño.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT"

if [ ! -f supabase/.temp/project-ref ]; then
  echo "el proyecto no está enlazado: \`supabase link --project-ref <ref>\` primero" >&2
  exit 2
fi

supabase/test.sh

supabase db push
supabase functions deploy start-run finish-run leaderboard report remoderate

cat <<'PASOS'

Pasos manuales del dueño (el script no toca secretos):
  1. supabase secrets set ANTHROPIC_API_KEY=<clave>
  2. supabase secrets set REMODERATE_SECRET=<un secreto largo al azar>
  3. En el panel (SQL editor), cargar en el Vault los dos valores del cron:
       select vault.create_secret('https://<ref>.supabase.co', 'ranking_project_url');
       select vault.create_secret('<el mismo REMODERATE_SECRET>', 'ranking_remoderate_secret');
  4. Si aprobaste la lista de palabras:
       deno run --allow-read --allow-write supabase/scripts/blocklist_to_sql.ts
       y volver a correr este script (la migración generada se aplica con db push).
  5. Probar: curl -X POST https://<ref>.supabase.co/functions/v1/remoderate -H "Authorization: Bearer <REMODERATE_SECRET>"
PASOS
