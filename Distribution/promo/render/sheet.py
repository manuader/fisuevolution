# Hoja de contacto de los previews: python3 sheet.py v2 [ancho]
import sys, glob
from PIL import Image
v = sys.argv[1]; w = int(sys.argv[2]) if len(sys.argv) > 2 else 270
fs = sorted(glob.glob(f'out/preview/{v}_t*.jpg'), key=lambda f: float(f.split('_t')[-1][:-4]))
h = int(w * 16 / 9); cols = min(len(fs), 8); rows = (len(fs) + cols - 1) // cols
sheet = Image.new('RGB', (w * cols, h * rows))
for i, f in enumerate(fs): sheet.paste(Image.open(f).resize((w, h)), ((i % cols) * w, (i // cols) * h))
sheet.save(f'out/sheet_{v}.jpg'); print(len(fs), 'frames')
