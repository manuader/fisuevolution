#!/bin/bash
# Abre el Estudio de assets de FisuEvolution: doble clic.
# Arranca el servidor en este equipo (127.0.0.1) y abre Safari.
# Dejá esta ventana abierta mientras trabajás; para terminar, cerrala.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
PROYECTO="$HOME/Desktop/projects/FisuEvolution"
PYTHON="$PROYECTO/Tools/asset-pipeline/.venv/bin/python"
for CARPETA in "$PROYECTO" "$PROYECTO/.claude/worktrees.nosync/v2-estudio-assets"; do
  if [ -f "$CARPETA/Tools/asset-studio/servidor.py" ]; then
    cd "$CARPETA" || exit 1
    exec "$PYTHON" "$CARPETA/Tools/asset-studio/servidor.py"
  fi
done
echo "No encontré el Estudio de assets en $PROYECTO."
echo "Pedile a un agente que lo integre (rama v2/estudio-assets)."
read -r -p "Apretá Enter para cerrar."
