#!/usr/bin/env bash
# Las consultas semanales del panel del valor por jugador (2.1 F7 T2), con psql, impresas como tablas.
# Lectura sola; las vistas y los guardianes están en supabase/migrations (…000003 y …000004).
# La URL de la base la pasa el dueño; nunca se guarda en el repo ni se imprime:
#   PANEL_DB_URL='postgresql://…' Tools/v21/panel.sh [semana|segmentos|brazos|retencion|ritmo|guardian|priors|todo]
#   Tools/v21/panel.sh --url 'postgresql://…' guardian
# Opciones por entorno: PANEL_EXP (experimento del guardián, default moments), PANEL_CONTROL (brazo de control,
# default control; en vej 'rules'), PANEL_VERSION (versión de moments para los priors, default 1).
set -euo pipefail

URL="${PANEL_DB_URL:-}"
if [ "${1:-}" = "--url" ]; then
  URL="${2:-}"
  shift 2 || true
fi
QUE="${1:-todo}"

if [ -z "$URL" ]; then
  echo "falta la URL de la base: PANEL_DB_URL='postgresql://…' $0 [consulta]" >&2
  exit 64
fi
if ! command -v psql >/dev/null 2>&1; then
  echo "falta psql (brew install libpq)" >&2
  exit 69
fi

EXP="${PANEL_EXP:-moments}"
CONTROL="${PANEL_CONTROL:-control}"
VERSION="${PANEL_VERSION:-1}"

consulta() {
  echo
  echo "== $1 =="
  # -v ON_ERROR_STOP: una vista que falta corta con error en vez de seguir callada. Las variables van como
  # variables de psql (:'x'); por stdin porque -c no las interpola.
  psql "$URL" --no-psqlrc -X -v ON_ERROR_STOP=1 -v exp="$EXP" -v control="$CONTROL" -v version="$VERSION" <<<"$2"
}

semana() {
  consulta "La semana: ingreso por instalación-día por segmento (7 días)" "
select segmento, moneda, sum(instalaciones) as instalaciones_dia, sum(impresiones) as impresiones,
       round(sum(ingreso), 2) as ingreso,
       round(sum(ingreso) / nullif(sum(instalaciones), 0), 4) as ingreso_por_instalacion_dia
from panel_value_daily
where dia >= (now() at time zone 'UTC')::date - 7
group by 1, 2 order by 1, 2"
}

segmentos() {
  consulta "Por segmento y formato (7 días)" "
select segmento, formato, moneda, sum(impresiones) as impresiones, round(sum(ingreso), 2) as ingreso
from panel_value_daily
where dia >= (now() at time zone 'UTC')::date - 7 and formato is not null
group by 1, 2, 3 order by 1, 5 desc"
}

brazos() {
  consulta "Por brazo: el embudo de las ofertas (7 días)" "
select exp, arm, ver, site, sum(mostradas) as mostradas, sum(aceptadas) as aceptadas,
       sum(completadas) as completadas,
       round(sum(completadas)::numeric / nullif(sum(mostradas), 0), 4) as conversion
from panel_offer_funnel
where dia >= (now() at time zone 'UTC')::date - 7
group by 1, 2, 3, 4 order by exp nulls first, arm, site"
}

retencion() {
  consulta "Retención D1/D7 por segmento y brazo (cohortes de 30 días)" "
select exp, arm, segmento, sum(instalaciones) as instalaciones,
       sum(d1_elegibles) as d1_n, round(sum(d1_retenidas)::numeric / nullif(sum(d1_elegibles), 0), 4) as d1,
       sum(d7_elegibles) as d7_n, round(sum(d7_retenidas)::numeric / nullif(sum(d7_elegibles), 0), 4) as d7
from panel_retention
where dia0 >= (now() at time zone 'UTC')::date - 30
group by 1, 2, 3 order by exp nulls first, arm, segmento"
}

ritmo() {
  consulta "Ritmo real: horas activas hasta cada tier (primera vida, 30+ instalaciones)" "
select segmento, tier, instalaciones, horas_p25, horas_p50, horas_p75
from panel_pacing
where prestige = 0 and instalaciones >= 30 order by segmento, tier"
}

guardian() {
  consulta "Guardián de retención ($EXP contra $CONTROL). 'apagar' sólo informa: apagar un brazo es editar la config" \
    "select * from panel_retention_guard(:'exp', :'control')"
}

priors() {
  consulta "Priors del bandido (moments, versión $VERSION)" "select * from panel_bandit_priors(:'version')"
}

case "$QUE" in
  semana) semana ;;
  segmentos) segmentos ;;
  brazos) brazos ;;
  retencion) retencion ;;
  ritmo) ritmo ;;
  guardian) guardian ;;
  priors) priors ;;
  todo) semana; segmentos; brazos; retencion; ritmo; guardian; priors ;;
  *) echo "uso: $0 [semana|segmentos|brazos|retencion|ritmo|guardian|priors|todo]" >&2; exit 64 ;;
esac
