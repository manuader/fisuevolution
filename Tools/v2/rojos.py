#!/usr/bin/env python3
"""Juzga una corrida de tests contra los rojos declarados del oráculo.

    rojos.py xcresult <suite> <bundle.xcresult>
    rojos.py unittest <suite> <salida-de-unittest.log>

Imprime una línea de resumen y termina en 0 sólo si corrió al menos un test y
todo rojo está en `rojos-declarados.txt` para esa suite. Un filtro
`-only-testing` mal escrito corre cero tests y Xcode lo da por bueno: por eso
cero tests también es rojo.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

DECLARED = Path(__file__).with_name("rojos-declarados.txt")


def declared_for(suite):
    fragments = []
    for line in DECLARED.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        tag, fragment = line.split(None, 1)
        if tag == suite:
            fragments.append(fragment.strip())
    return fragments


def from_xcresult(bundle):
    raw = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", bundle],
        check=True, capture_output=True, text=True,
    ).stdout
    summary = json.loads(raw)
    failures = [
        f.get("testIdentifierString") or f.get("testName") or "?"
        for f in summary.get("testFailures", [])
    ]
    counts = (summary.get("passedTests", 0), summary.get("failedTests", 0), summary.get("skippedTests", 0))
    return counts, failures


def from_unittest_log(log):
    text = Path(log).read_text(encoding="utf-8", errors="replace")
    failures = re.findall(r"^(?:FAIL|ERROR): (\S+) \(", text, re.MULTILINE)
    ran = re.search(r"^Ran (\d+) tests?", text, re.MULTILINE)
    total = int(ran.group(1)) if ran else 0
    skipped = re.search(r"skipped=(\d+)", text)
    skipped = int(skipped.group(1)) if skipped else 0
    return (total - len(failures) - skipped, len(failures), skipped), failures


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("xcresult", "unittest"):
        sys.exit(__doc__)
    mode, suite, path = sys.argv[1:]
    (passed, failed, skipped), failures = (from_xcresult if mode == "xcresult" else from_unittest_log)(path)
    fragments = declared_for(suite)

    unexpected = [f for f in failures if not any(fr in f for fr in fragments)]
    healed = [fr for fr in fragments if not any(fr in f for f in failures)]

    print(f"{suite}: {passed} verdes · {failed} rojos · {skipped} salteados")
    for f in failures:
        print(f"  {'ROJO NUEVO' if f in unexpected else 'rojo declarado'}: {f}")
    for fr in healed:
        print(f"  ℹ️  el rojo declarado '{fr}' no falló: si se arregló, sacalo de rojos-declarados.txt")

    if passed + failed == 0:
        print(f"  ROJO: no corrió ningún test (¿filtro -only-testing mal escrito?)")
        sys.exit(1)
    sys.exit(1 if unexpected else 0)


if __name__ == "__main__":
    main()
