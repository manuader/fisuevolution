#!/bin/bash
# Doble clic: arranca la revisión de islas y la abre en el navegador.
cd "$(dirname "$0")" || exit 1
exec /usr/bin/env python3 servir.py
