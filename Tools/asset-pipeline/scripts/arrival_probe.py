"""La LLEGADA del cofre, frame a frame: donde se traba "al principio".

Detecta la llegada del overlay por la caida de brillo (el telon al 55 %),
y desde ahi imprime 2,5 s a 60 CFR como una tira de simbolos — un caracter
por frame: 'x' = cambio, '.' = identico al anterior (umbral FINO, para que
la respiracion y el fade cuenten como movimiento) — mas las corridas de
identicos >= 66 ms. Un trabon del resorte de entrada se ve como una hilera
de puntos en medio de las x.

Uso: python arrival_probe.py grabacion.mp4
"""
import subprocess
import sys
from pathlib import Path

import numpy as np

SRC = Path(sys.argv[1])
FPS = 60
W, H = 180, 320
FINE = 0.08  # umbral fino: el fade y la respiracion son cambios chicos

raw = subprocess.run(
    ["ffmpeg", "-v", "error", "-i", str(SRC),
     "-vf", f"fps={FPS},scale={W}:{H},format=gray", "-f", "rawvideo", "-"],
    capture_output=True, check=True,
).stdout
frames = np.frombuffer(raw, dtype=np.uint8)
n = len(frames) // (W * H)
frames = frames[: n * W * H].reshape(n, H, W).astype(np.int16)

brightness = frames.mean(axis=(1, 2))
diffs = np.abs(np.diff(frames, axis=0)).mean(axis=(1, 2))

# La llegada: primer frame (pasados 2 s de splash) cuyo brillo cae >12 %
# respecto de medio segundo antes.
arrival = None
for i in range(2 * FPS + FPS // 2, n):
    before = brightness[i - FPS // 2]
    if before > 0 and (before - brightness[i]) / before > 0.12:
        arrival = i
        break
if arrival is None:
    print("no encontre la llegada (sin caida de brillo)")
    sys.exit(1)

t0 = arrival / FPS
print(f"{SRC.name}: llegada del overlay a los {t0:.2f} s (frame {arrival})")
end = min(n - 1, arrival + int(2.5 * FPS))
seg = diffs[arrival - 1 : end]  # diff[i] compara frame i+1 con i

line = "".join("x" if d > FINE else "." for d in seg)
for s in range(0, len(line), FPS // 2):
    print(f"  +{s / FPS:4.2f}s  {line[s : s + FPS // 2]}")

print("\n== corridas de identicos >= 66 ms tras la llegada ==")
run = None
found = False
for k, d in enumerate(seg):
    same = d <= FINE
    if same and run is None:
        run = k
    elif not same and run is not None:
        if k - run >= 4:
            print(f"  +{run / FPS:.2f}s: {(k - run) * 1000 // FPS} ms quieto")
            found = True
        run = None
if run is not None and len(seg) - run >= 4:
    print(f"  +{run / FPS:.2f}s: {(len(seg) - run) * 1000 // FPS} ms quieto (hasta el corte)")
    found = True
if not found:
    print("  ninguna")
