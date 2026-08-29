"""Fluidez de una grabacion del sim, sin promedios que escondan trabones.

Nacio en la sesion del 2026-08-28 (sexta): el "24 fps clavados" del promedio
por segundo era verdad Y la traba del dueño tambien — 150+133 ms de frames
identicos en el empalme PNG->video, invisibles para el promedio. Por eso
mide LAS DOS cosas, sobre la grabacion normalizada a 60 CFR (la grabacion
del sim es VFR: contar sobre los frames crudos corre los buckets, y el
frame n NO es n/60 s):
  1. frames DISTINTOS por segundo (fluidez sostenida)
  2. las corridas de frames identicos >= 100 ms, con timestamp (los
     trabones puntuales que el jugador SI ve)

Uso: .venv/bin/python scripts/analyze_recording.py grabacion.mp4 [t_ini] [t_fin]
(la grabacion sale de `xcrun simctl io <udid> recordVideo --codec h264`)
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

SRC = Path(sys.argv[1])
T0 = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
T1 = float(sys.argv[3]) if len(sys.argv) > 3 else 1e9
FPS = 60
# Escala chica: el diff es de movimiento, no de detalle. gray para robustez.
W, H = 180, 320

cmd = [
    "ffmpeg", "-v", "error", "-i", str(SRC),
    "-vf", f"fps={FPS},scale={W}:{H},format=gray",
    "-f", "rawvideo", "-",
]
raw = subprocess.run(cmd, capture_output=True, check=True).stdout
frames = np.frombuffer(raw, dtype=np.uint8)
n = len(frames) // (W * H)
frames = frames[: n * W * H].reshape(n, H, W).astype(np.int16)

diffs = np.abs(np.diff(frames, axis=0)).mean(axis=(1, 2))  # diff medio 0..255
DISTINCT = 0.30  # debajo de esto, el frame es "el mismo" (ruido de encode)

i0, i1 = int(T0 * FPS), min(n - 1, int(T1 * FPS))
window = diffs[i0:i1]

print(f"{SRC.name}: {n} frames a {FPS} fps ({n / FPS:.2f} s)")
print(f"ventana [{T0:.1f}, {i1 / FPS:.1f}] s")

print("\n== frames distintos por segundo ==")
for s in range(i0 // FPS, (i1 + FPS - 1) // FPS):
    seg = diffs[max(s * FPS, i0) : min((s + 1) * FPS, i1)]
    if len(seg) == 0:
        continue
    distinct = int((seg > DISTINCT).sum())
    bar = "#" * (distinct // 2)
    print(f"  {s:3d}s: {distinct:2d} {bar}")

print("\n== corridas de frames identicos (>= 100 ms) ==")
run_start = None
found = False
for k in range(len(window)):
    same = window[k] <= DISTINCT
    if same and run_start is None:
        run_start = k
    elif not same and run_start is not None:
        length = k - run_start
        if length >= FPS // 10:  # 100 ms
            t = (i0 + run_start) / FPS
            print(f"  {t:7.2f}s: {length * 1000 // FPS:4d} ms quieto")
            found = True
        run_start = None
if run_start is not None and (len(window) - run_start) >= FPS // 10:
    t = (i0 + run_start) / FPS
    print(f"  {t:7.2f}s: {(len(window) - run_start) * 1000 // FPS:4d} ms quieto (hasta el final)")
    found = True
if not found:
    print("  ninguna: nada quieto >= 100 ms en la ventana")
