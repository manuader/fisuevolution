#!/bin/bash
# Batch de arte de skins — CORRER DESDE Terminal.app.
#
# El runner escribe el prompt con keystrokes reales de macOS (System Events), y
# ese permiso de Accesibilidad está otorgado a Terminal. Desde el shell de un
# agente falla con "osascript is not allowed to send keystrokes (1002)": ahí el
# proceso responsable es un bundle anidado y versionado, no una app que se pueda
# autorizar de forma estable.
#
#   bash scripts/run_skins_batch.sh
#
# Valida UN asset primero y, sólo si sale bien, larga los 37 restantes.
# Reanudable: el checkpoint saltea lo ya hecho, así que se puede cortar y
# volver a lanzar sin perder nada.

set -u
cd "$(dirname "$0")/.." || exit 1

PY=".venv/bin/python"
RUNNER="scripts/gemini_selenium_runner.py"
# Obligatorio para skins: la referencia adjunta es el MISMO personaje, y con el
# umbral por defecto (12) el filtro anti-falsos-positivos puede descartar la
# skin legítima por parecerse demasiado a su propia referencia.
THRESHOLD=5

echo "==> Verificando permiso de Accesibilidad…"
if ! $PY -c "
import ctypes, ctypes.util, sys
lib = ctypes.cdll.LoadLibrary(ctypes.util.find_library('ApplicationServices'))
sys.exit(0 if lib.AXIsProcessTrusted() else 1)
"; then
    echo "   ✗ Esta app no tiene Accesibilidad."
    echo "     Ajustes del Sistema → Privacidad y seguridad → Accesibilidad → activar Terminal."
    exit 1
fi
echo "   ✓ OK"

echo "==> Chrome dedicado en :9222…"
if ! curl -s --max-time 4 http://127.0.0.1:9222/json/version >/dev/null; then
    $PY scripts/launch_gemini_chrome.py || exit 1
    sleep 4
fi
echo "   ✓ OK (si Gemini pide login, hacelo en ESA ventana y volvé a correr)"

echo
echo "==> Validando un asset suelto antes del batch…"
$PY "$RUNNER" --only homeless__second_life --process --ref-threshold "$THRESHOLD" --timeout 300
if [ ! -f dropbox/procesadas/homeless__second_life.png ]; then
    echo
    echo "   ✗ El asset de prueba no llegó a procesadas/. No lanzo el batch."
    echo "     Revisá el error de arriba y state/selenium-run.json."
    exit 1
fi
echo "   ✓ El circuito completo funciona (generación → rembg → atlas)"

echo
echo "==> Batch de los assets restantes (~2 h). No uses la Mac mientras corre:"
echo "    el runner tipea en Chrome y necesita el foco."
exec caffeinate -is $PY "$RUNNER" \
    --process --pause 3 --timeout 260 --ref-threshold "$THRESHOLD"
