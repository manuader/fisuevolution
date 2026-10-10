#!/usr/bin/env python3
"""Sirve la revision de islas en este mismo equipo y guarda lo que se pinta.

El navegador solo no puede escribir en disco: esto le da donde. Guarda el PNG
limpio en `limpias/<sprite>.png` y lo pintado en `marcas.json`, que es lo que
`aplicar_limpias.py` lleva al juego. Solo usa la biblioteca estandar.

    python3 servir.py              # elige un puerto libre y abre el navegador
    python3 servir.py --no-abrir --puerto 8799
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import socket
import threading
import webbrowser
from datetime import datetime
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

CARPETA = Path(__file__).resolve().parent
LIMPIAS = CARPETA / "limpias"
MARCAS = CARPETA / "marcas.json"
CLAVE_VALIDA = re.compile(r"^[a-z0-9_]+$")
ID_VALIDO = re.compile(r"^[sh][0-9]+$")
FIRMA_PNG = b"\x89PNG\r\n\x1a\n"
PRIMER_PUERTO = 8765

_escritura = threading.Lock()


def leer_marcas() -> dict:
    if not MARCAS.exists():
        return {}
    return json.loads(MARCAS.read_text(encoding="utf-8"))


def escribir_atomico(ruta: Path, datos: bytes) -> None:
    temporal = ruta.with_name(ruta.name + ".tmp")
    temporal.write_bytes(datos)
    temporal.replace(ruta)


def guardar(pedido: dict) -> dict:
    clave = str(pedido.get("clave", ""))
    if not CLAVE_VALIDA.match(clave):
        raise ValueError("nombre de sprite invalido")
    rojas = [i for i in pedido.get("rojas", []) if ID_VALIDO.match(str(i))]
    verdes = [i for i in pedido.get("verdes", []) if ID_VALIDO.match(str(i))]
    png = str(pedido.get("png", ""))
    prefijo = "data:image/png;base64,"
    if not png.startswith(prefijo):
        raise ValueError("no llego la imagen")
    imagen = base64.b64decode(png[len(prefijo):], validate=True)
    if not imagen.startswith(FIRMA_PNG):
        raise ValueError("la imagen no es un PNG")

    with _escritura:
        LIMPIAS.mkdir(exist_ok=True)
        escribir_atomico(LIMPIAS / f"{clave}.png", imagen)
        marcas = leer_marcas()
        marcas[clave] = {
            "rojas": sorted(set(rojas)),
            "verdes": sorted(set(verdes)),
            "origen": str(pedido.get("origen", "")),
            "listo": True,
            "guardado": datetime.now().isoformat(timespec="seconds"),
        }
        escribir_atomico(MARCAS, (json.dumps(marcas, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode())
    return marcas[clave]


class Revision(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def responder(self, codigo: int, cuerpo: dict) -> None:
        datos = json.dumps(cuerpo, ensure_ascii=False).encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(datos)))
        self.end_headers()
        self.wfile.write(datos)

    def do_GET(self) -> None:
        if self.path.split("?")[0] == "/api/marcas":
            self.responder(200, leer_marcas())
            return
        super().do_GET()

    def do_POST(self) -> None:
        if self.path != "/api/guardar":
            self.responder(404, {"error": "no existe"})
            return
        try:
            largo = int(self.headers.get("Content-Length", 0))
            marca = guardar(json.loads(self.rfile.read(largo)))
        except (ValueError, json.JSONDecodeError) as problema:
            self.responder(400, {"error": str(problema)})
            return
        self.responder(200, {"ok": True, "marca": marca})

    def log_message(self, formato: str, *args) -> None:
        if self.command == "POST":
            super().log_message(formato, *args)


def puerto_libre(desde: int) -> int:
    for puerto in range(desde, desde + 40):
        with socket.socket() as prueba:
            if prueba.connect_ex(("127.0.0.1", puerto)) != 0:
                return puerto
    raise SystemExit("No encontre un puerto libre.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--puerto", type=int, default=0)
    parser.add_argument("--no-abrir", action="store_true")
    args = parser.parse_args()

    puerto = args.puerto or puerto_libre(PRIMER_PUERTO)
    servidor = ThreadingHTTPServer(("127.0.0.1", puerto), partial(Revision, directory=str(CARPETA)))
    direccion = f"http://127.0.0.1:{puerto}/"
    print(f"Revisión de islas abierta en {direccion}")
    print("Dejá esta ventana abierta mientras trabajás. Para terminar: cerrala (o Ctrl+C).")
    if not args.no_abrir:
        threading.Timer(0.5, webbrowser.open, args=(direccion,)).start()
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        servidor.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
