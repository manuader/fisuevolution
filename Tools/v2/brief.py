#!/usr/bin/env python3
"""Recorta una tarea de un plan a su propio archivo, para que el agente lea sólo eso.

    Tools/v2/brief.py <plan.md> <N> <salida.md>

Copia el encabezado del plan hasta la primera tarea (reglas globales, archivos) y la
sección `### Task N:` completa, hasta la próxima tarea o el próximo `## `.
"""
import re
import sys
from pathlib import Path

plan, number, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
lines = plan.read_text(encoding="utf-8").split("\n")
task_re = re.compile(r"^### Task (\w+):")
first = next(i for i, l in enumerate(lines) if task_re.match(l))
start = next(i for i, l in enumerate(lines) if (m := task_re.match(l)) and m.group(1) == number)
end = next((i for i in range(start + 1, len(lines))
            if task_re.match(lines[i]) or lines[i].startswith("## ")), len(lines))
header = lines[:first]
out.write_text("\n".join(header + ["", "---", ""] + lines[start:end]) + "\n", encoding="utf-8")
print(f"{out}: encabezado {first} líneas + Task {number} {end - start} líneas")
