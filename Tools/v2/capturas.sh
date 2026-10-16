#!/bin/bash
# Las capturas de la ficha de App Store, en los slots de iPhone y iPad y los dos idiomas.
#
#     Tools/v2/capturas.sh [--device "<nombre>"] [--lang en|es] [--sin-review]
#
# Sin argumentos saca todo: iPhone 17 Pro Max (6,9") y iPad Pro 13-inch (M5), en
# inglés y en castellano (los slots que App Store Connect exige hoy; los demás
# tamaños de iPhone se escalan del de 6,9"), más las tres capturas de revisión
# de las ofertas. `--device "iPhone 17 Pro"` agrega el slot opcional de 6,3".
# Crea un simulador propio (iOS 26.5) por dispositivo, corre
# `AppStoreScreenshotTests` por idioma, saca los adjuntos del .xcresult y valida
# el tamaño de cada PNG. Los simuladores se borran al salir. Nada se sube a
# ningún lado.
#
# Salida: build/capturas/2.0/<dispositivo>/<idioma>/NN-nombre.png  (diez por corrida)
#         build/capturas/2.0/review/offer_<id>.png  (iPhone 17 Pro Max, en inglés;
#         las sube el dueño con `releaseops asc screenshot offer_<id> <png>`)
#
# En Debug `--uitest-video` queda forzado a quieto: las capturas son pósteres.

set -o pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO" || exit 2

# nombre del dispositivo -> ancho x alto exactos del slot de App Store Connect
size_for() {
  case "$1" in
    "iPhone 17 Pro Max") echo "1320x2868" ;;
    "iPhone 17 Pro") echo "1206x2622" ;;
    "iPad Pro 13-inch (M5)") echo "2064x2752" ;;
    *) echo "" ;;
  esac
}
ALL_DEVICES=("iPhone 17 Pro Max" "iPad Pro 13-inch (M5)")
REVIEW_DEVICE="iPhone 17 Pro Max"
OFFERS=(bienvenida renacer mudanza)   # los productId com.fisuevolution.iap.offer_<id> de release.json
EXPECTED=10                           # capturas del guion por dispositivo e idioma

DEVICES=("${ALL_DEVICES[@]}")
LANGS=(en es)
REVIEW=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICES=("$2"); shift 2 ;;
    --lang) LANGS=("$2"); shift 2 ;;
    --sin-review) REVIEW=0; shift ;;
    *) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  esac
done
for device in "${DEVICES[@]}"; do
  [[ -n "$(size_for "$device")" ]] || { echo "dispositivo sin slot conocido: $device" >&2; exit 2; }
done
for lang in "${LANGS[@]}"; do
  [[ "$lang" == "en" || "$lang" == "es" ]] || { echo "idioma inválido: $lang (en|es)" >&2; exit 2; }
done

DD="$REPO/build/DD-capturas.noindex"
OUT="$REPO/build/capturas/2.0"
WORK="$REPO/build/capturas/.trabajo-$$"
mkdir -p "$OUT" "$WORK"

SIMS=()
cleanup() {
  for udid in "${SIMS[@]}"; do
    xcrun simctl shutdown "$udid" >/dev/null 2>&1
    xcrun simctl delete "$udid" >/dev/null 2>&1
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

SWIFT_FLAGS='OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations'
FAILED=()

# Sin Package.resolved (el .xcodeproj no se versiona) la resolución automática
# tiene que poder correr; con él, queda fija.
RESOLVED="$REPO/FisuEvolution.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
PKG_FLAGS=()
[[ -f "$RESOLVED" ]] && PKG_FLAGS=(-disableAutomaticPackageResolution -skipPackageUpdates)

echo "▶ xcodegen + build-for-testing" >&2
/opt/homebrew/bin/xcodegen generate >"$WORK/xcodegen.log" 2>&1 || { cat "$WORK/xcodegen.log"; exit 1; }

# extract_attachments <carpeta exportada> <destino> <regex con un grupo>: copia cada adjunto
# cuyo nombre coincide a <destino>/<grupo>.png (una repetición del test reemplaza a la anterior).
extract_attachments() {
  python3 - "$1" "$2" "$3" <<'PY'
import json, os, re, shutil, sys
raw, dest, pattern = sys.argv[1:4]
manifest = json.load(open(os.path.join(raw, "manifest.json")))
for test in manifest:
    for att in test.get("attachments", []):
        m = re.match(pattern, att.get("suggestedHumanReadableName", ""))
        if m:
            shutil.copy(os.path.join(raw, att["exportedFileName"]), os.path.join(dest, m.group(1) + ".png"))
PY
}

# Un simulador por dispositivo: se crea, se usa y se borra antes del siguiente.
slug() { echo "$1" | tr 'A-Z ()' 'a-z--' | tr -s '-' | sed 's/-$//'; }

for device in "${DEVICES[@]}"; do
  expected="$(size_for "$device")"
  udid=$(xcrun simctl create "capturas-$$-$(slug "$device")" "$device" "com.apple.CoreSimulator.SimRuntime.iOS-26-5") \
    || { echo "❌ no se pudo crear el simulador de $device" >&2; FAILED+=("$device"); continue; }
  SIMS+=("$udid")

  if [[ ! -e "$WORK/built" ]]; then
    xcodebuild build-for-testing -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
      -destination "id=$udid" -derivedDataPath "$DD" "${PKG_FLAGS[@]}" "$SWIFT_FLAGS" >"$WORK/build.log" 2>&1 \
      || { echo "❌ no compila (log: $WORK/build.log)"; tail -30 "$WORK/build.log"; cp "$WORK/build.log" "$OUT/build-fallido.log"; exit 1; }
    touch "$WORK/built"
  fi

  for lang in "${LANGS[@]}"; do
    if [[ "$lang" == "en" ]]; then suffix="EnIngles"; else suffix="EnCastellano"; fi
    bundle="$WORK/$(slug "$device")-$lang.xcresult"
    dest="$OUT/$(slug "$device")/$lang"
    rm -rf "$dest" "$bundle"; mkdir -p "$dest"
    echo "▶ $device · $lang" >&2
    only=()
    for t in ElRecorrido ElVisitante LaRecompensa LaMarcha LosPersonajes ElCofre; do
      only+=(-only-testing:"FisuEvolutionUITests/AppStoreScreenshotTests/testCaptura${t}${suffix}")
    done
    xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
      -destination "id=$udid" -derivedDataPath "$DD" -parallel-testing-enabled NO \
      "${PKG_FLAGS[@]}" -resultBundlePath "$bundle" "${only[@]}" >"$WORK/test-$lang.log" 2>&1
    status=$?
    cp "$WORK/test-$lang.log" "$dest/../test-$lang.log"
    [[ $status -eq 0 ]] || { echo "⚠️  $device · $lang: xcodebuild salió con $status (log: $dest/../test-$lang.log)" >&2; FAILED+=("$device/$lang"); }

    raw="$WORK/raw-$(slug "$device")-$lang"
    rm -rf "$raw"; mkdir -p "$raw"
    xcrun xcresulttool export attachments --path "$bundle" --output-path "$raw" >/dev/null 2>&1
    extract_attachments "$raw" "$dest" 'captura-(\d\d-[a-z-]+)'

    count=$(ls "$dest"/*.png 2>/dev/null | wc -l | tr -d ' ')
    for png in "$dest"/*.png; do
      [[ -e "$png" ]] || continue
      w=$(sips -g pixelWidth "$png" | awk '/pixelWidth/ {print $2}')
      h=$(sips -g pixelHeight "$png" | awk '/pixelHeight/ {print $2}')
      if [[ "${w}x${h}" != "$expected" ]]; then
        echo "❌ $(basename "$png"): ${w}x${h}, se esperaba $expected" >&2
        FAILED+=("$device/$lang/$(basename "$png")")
      fi
    done
    echo "   $device · $lang: $count/$EXPECTED capturas en $dest" >&2
    [[ "$count" -eq "$EXPECTED" ]] || FAILED+=("$device/$lang: $count de $EXPECTED")
  done

  # Las capturas de revisión de las ofertas: una vez, en el slot de 6,9", en inglés.
  if (( REVIEW )) && [[ "$device" == "$REVIEW_DEVICE" ]]; then
    bundle="$WORK/review.xcresult"
    dest="$OUT/review"
    rm -rf "$dest" "$bundle"; mkdir -p "$dest"
    echo "▶ $device · revisión de las ofertas" >&2
    only=()
    for id in "${OFFERS[@]}"; do
      only+=(-only-testing:"FisuEvolutionUITests/AppStoreScreenshotTests/testCapturaLaOferta$(tr 'a-z' 'A-Z' <<<"${id:0:1}")${id:1}")
    done
    xcodebuild test-without-building -scheme FisuEvolution -sdk iphonesimulator -configuration Debug \
      -destination "id=$udid" -derivedDataPath "$DD" -parallel-testing-enabled NO \
      "${PKG_FLAGS[@]}" -resultBundlePath "$bundle" "${only[@]}" >"$WORK/test-review.log" 2>&1
    status=$?
    cp "$WORK/test-review.log" "$OUT/test-review.log"
    [[ $status -eq 0 ]] || { echo "⚠️  revisión: xcodebuild salió con $status (log: $OUT/test-review.log)" >&2; FAILED+=("review"); }
    raw="$WORK/raw-review"
    rm -rf "$raw"; mkdir -p "$raw"
    xcrun xcresulttool export attachments --path "$bundle" --output-path "$raw" >/dev/null 2>&1
    extract_attachments "$raw" "$dest" 'oferta-(offer_[a-z]+)'
    for id in "${OFFERS[@]}"; do
      png="$dest/offer_$id.png"
      if [[ ! -e "$png" ]]; then FAILED+=("review/offer_$id: falta"); continue; fi
      w=$(sips -g pixelWidth "$png" | awk '/pixelWidth/ {print $2}')
      h=$(sips -g pixelHeight "$png" | awk '/pixelHeight/ {print $2}')
      echo "   offer_$id.png: ${w}x${h}" >&2
      [[ "${w}x${h}" == "$expected" ]] || { echo "❌ offer_$id.png: ${w}x${h}, se esperaba $expected" >&2; FAILED+=("review/offer_$id"); }
    done
  fi
done

if (( ${#FAILED[@]} )); then
  echo "ROJO: ${FAILED[*]}" >&2
  exit 1
fi
echo "VERDE: $OUT"
