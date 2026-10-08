#!/bin/bash
# Oráculo del run de la 2.0 (PLAN-v2 §0): termina en 0 sólo si todo está verde.
#
#     Tools/v2/oraculo.sh tarea [Clase…]        # EconomyKit + build + sólo esas clases de unit
#     Tools/v2/oraculo.sh rapido   [--limpio]   # EconomyKit + build + unit (iOS 26.5) + Release
#     Tools/v2/oraculo.sh completo [--limpio]   # rapido + Store (18.6) + UI en la matriz
#                                               #   + pipeline + pacing-sim
#
# `tarea` es el chequeo de un agente antes de su commit: compila y corre sólo
# las clases de test que tocó (p. ej. `tarea BoardChangeWiringTests
# LifecycleTests`). La suite unit entera y el Release los corre el controlador
# en el `rapido` de integración, una vez por ola en vez de una por tarea.
#
# Sigue la receta de HANDOFF §6: simuladores propios por UDID (se borran al
# salir), unit ANTES que UI en cada simulador, sin paralelismo y DerivedData
# absoluto. Las tres suites de Store corren en iOS 18.6 porque StoreKit Testing
# está roto en el runtime 26 (trampa 30).
#
# `--limpio` borra el DerivedData antes de compilar: el build incremental NO
# recompila los atlas (trampa 1), así que después de tocar arte hace falta.
#
# Los rojos tolerados viven en Tools/v2/rojos-declarados.txt. Cada corrida deja
# sus logs y xcresult en build/oraculo/<fecha>-<modo>/.

# Sin `set -u`: el bash 3.2 de macOS trata un array vacío como variable sin definir.
set -o pipefail

MODE="${1:-}"
if [[ "$MODE" != "tarea" && "$MODE" != "rapido" && "$MODE" != "completo" ]]; then
  sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi
shift
CLEAN=""
TASK_TESTS=()
for arg in "$@"; do
  if [[ "$arg" == "--limpio" ]]; then CLEAN="--limpio"; else TASK_TESTS+=(-only-testing:"FisuEvolutionTests/$arg"); fi
done

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
# xcodebuild toma el proyecto del directorio actual: sin esto, correr el oráculo
# de otro worktree por su ruta absoluta compila las fuentes del worktree desde
# el que se lo llama.
cd "$REPO" || exit 2
TOOLS="$REPO/Tools/v2"
# `.noindex`: Spotlight no indexa los gigas de DerivedData de cada worktree.
DD="$REPO/build/DD-oraculo.noindex"
OUT="$REPO/build/oraculo/$(date +%Y%m%d-%H%M%S)-$MODE"
mkdir -p "$OUT"

# Sin esto el header de StoreKitTest rompe el build con -warnings-as-errors.
SWIFT_FLAGS='OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
STORE_UNIT=(-only-testing:FisuEvolutionTests/StoreManagerTests -only-testing:FisuEvolutionTests/StoreProductsTests)
STORE_UI=(-only-testing:FisuEvolutionUITests/StoreUITests)

FAILED=()
SUMMARY="$OUT/resumen.txt"

note() { echo "$*" | tee -a "$SUMMARY"; }

step() {
  local name="$1"; shift
  local started=$SECONDS
  echo "▶ $name" >&2
  if "$@" >"$OUT/$name.log" 2>&1; then
    note "✅ $name ($((SECONDS - started)) s)"
  else
    note "❌ $name ($((SECONDS - started)) s) — log: $OUT/$name.log"
    FAILED+=("$name")
  fi
}

SIMS=()
cleanup() {
  for udid in "${SIMS[@]}"; do
    xcrun simctl shutdown "$udid" >/dev/null 2>&1
    xcrun simctl delete "$udid" >/dev/null 2>&1
  done
}
trap cleanup EXIT

# Deja el UDID en la variable $2. No se usa `$(…)`: en un subshell el simulador
# no llegaría a SIMS y quedaría huérfano al salir. El dispositivo es el tercer
# argumento (por defecto, el iPhone 16 Pro).
new_sim() {
  local udid device="${3:-iPhone 16 Pro}"
  udid=$(xcrun simctl create "oraculo-$1-$$" "$device" "com.apple.CoreSimulator.SimRuntime.iOS-$1") || return 1
  SIMS+=("$udid")
  printf -v "$2" '%s' "$udid"
}

run_tests() {
  local suite="$1" udid="$2"; shift 2
  local bundle="$OUT/$suite.xcresult"
  xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
    -destination "id=$udid" -derivedDataPath "$DD" -parallel-testing-enabled NO \
    -resultBundlePath "$bundle" "$@"
  # El veredicto lo da la lista de rojos declarados, no el exit de xcodebuild.
  python3 "$TOOLS/rojos.py" xcresult "$suite" "$bundle" | tee "$OUT/$suite.veredicto"
}

economykit() {
  swift test --package-path "$REPO/Packages/EconomyKit" >"$OUT/economykit-tests.log" 2>&1
  local status=$?
  local line
  line=$(grep -m1 -E 'Test run with [0-9]+ tests' "$OUT/economykit-tests.log" | sed -E 's/.*Test run with ([0-9]+) tests.* (passed|failed).*/\1 tests, \2/')
  echo "economykit: ${line:-sin resumen}" | tee "$OUT/economykit.veredicto"
  return $status
}

generate() { (cd "$REPO" && /opt/homebrew/bin/xcodegen generate); }

build_for_testing() {
  [[ "$CLEAN" == "--limpio" ]] && rm -rf "$DD"
  xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
    -destination "id=$SIM26" -derivedDataPath "$DD" "$SWIFT_FLAGS"
}

pipeline() {
  local venv="$REPO/Tools/asset-pipeline/.venv"
  # Un worktree no tiene .venv propio: se usa el del checkout principal.
  [[ -x "$venv/bin/python" ]] || venv="$(dirname "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)")/Tools/asset-pipeline/.venv"
  (cd "$REPO/Tools/asset-pipeline" && "$venv/bin/python" -m unittest discover -s tests) >"$OUT/pipeline-tests.log" 2>&1
  python3 "$TOOLS/rojos.py" unittest pipeline "$OUT/pipeline-tests.log" | tee "$OUT/pipeline.veredicto"
}

pacing_sim() {
  local data="$REPO/FisuEvolution/Resources"
  # Su `.build` incremental no ve los archivos nuevos de EconomyKit ("cannot
  # find type 'PriceCushion'", relevo 9): si no compila, se borra y se reintenta.
  swift build --package-path "$REPO/Tools/pacing-sim" >/dev/null 2>&1 \
    || rm -rf "$REPO/Tools/pacing-sim/.build"
  swift run --package-path "$REPO/Tools/pacing-sim" pacing-sim \
    --economy "$data/Data/economy.json" --tiers "$data/Data/tiers.json" \
    --upgrades "$data/Config/upgrades.json" >"$OUT/pacing-report.txt" 2>&1 || return 1
  # Es un reporte, no un veredicto: el contrato lo juzga PacingTests en unit.
  local god reincarnations
  god=$(grep -m1 '^  dios:' "$OUT/pacing-report.txt" | sed 's/^ *dios: *//')
  reincarnations=$(grep -m1 '^  reencarnaciones:' "$OUT/pacing-report.txt" | awk '{print $2}')
  echo "pacing-sim: Dios en ${god:-?} · ${reincarnations:-?} reencarnaciones" | tee "$OUT/pacing-sim.veredicto"
}

release_build() {
  xcodebuild build -scheme FisuEvolution -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath "$DD-release" CODE_SIGNING_ALLOWED=NO >"$OUT/release-build.log" 2>&1 || return 1
  local warnings
  # Los avisos de TextureAtlas al partir un atlas grande en varias hojas no son
  # del compilador: vienen de los atlas de personajes y son esperables.
  warnings=$(grep ': warning:' "$OUT/release-build.log" | grep -v '^TextureAtlas: warning: Splitting' | sort -u | wc -l | tr -d ' ')
  echo "release: $warnings warnings del compilador" | tee "$OUT/release.veredicto"
  [[ "$warnings" -eq 0 ]]
}

note "Oráculo $MODE · $(git -C "$REPO" rev-parse --short HEAD) · $(date '+%F %T')"

new_sim 26-5 SIM26 || { note "❌ no se pudo crear el simulador 26.5"; exit 1; }
step economykit economykit
step xcodegen generate
step build-for-testing build_for_testing
if [[ " ${FAILED[*]} " == *" build-for-testing "* ]]; then
  note "ROJO: no compila, no se corren los tests"
  exit 1
fi
if [[ "$MODE" == "tarea" ]]; then
  (( ${#TASK_TESTS[@]} )) && step unit run_tests unit "$SIM26" "${TASK_TESTS[@]}"
else
  step unit run_tests unit "$SIM26" -only-testing:FisuEvolutionTests \
    -skip-testing:FisuEvolutionTests/StoreManagerTests -skip-testing:FisuEvolutionTests/StoreProductsTests
  step release release_build
fi

if [[ "$MODE" == "completo" ]]; then
  new_sim 18-6 SIM18 || { note "❌ no se pudo crear el simulador 18.6"; exit 1; }
  step store-unit run_tests store-unit "$SIM18" "${STORE_UNIT[@]}"
  step ui run_tests ui "$SIM26" -only-testing:FisuEvolutionUITests -skip-testing:FisuEvolutionUITests/StoreUITests
  step store-ui run_tests store-ui "$SIM18" "${STORE_UI[@]}"
  new_sim 26-5 SIMIPAD "iPad Pro 13-inch (M4)" || { note "❌ no se pudo crear el iPad"; exit 1; }
  step ipad-ui run_tests ipad-ui "$SIMIPAD" -only-testing:FisuEvolutionUITests/IPadLayoutUITests
  step pipeline pipeline
  step pacing-sim pacing_sim
fi

for verdict in "$OUT"/*.veredicto; do
  [[ -e "$verdict" ]] && head -1 "$verdict" | sed 's/^/   /' | tee -a "$SUMMARY"
done

if (( ${#FAILED[@]} )); then
  note "ROJO: ${FAILED[*]}"
  exit 1
fi
note "VERDE"
