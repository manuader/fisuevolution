#!/usr/bin/env python3
"""El Estudio de assets: un servidor local (127.0.0.1) y su pagina.

    <venv>/bin/python Tools/asset-studio/servidor.py            # abre Safari
    <venv>/bin/python Tools/asset-studio/servidor.py --no-abrir --puerto 8811

Al arrancar arma el catalogo del juego, lo sincroniza con el registro y, la
primera vez, importa el trabajo previo (`registro.importar_previo`). Todo lo que
la pagina hace pasa por la API de abajo; el navegador nunca escribe un PNG: lo
pide, y el PNG lo rehace `recorte.py` desde el corte y las marcas.

Solo biblioteca estandar para servir; numpy/scipy/PIL/rembg para la imagen.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import mimetypes
import re
import shutil
import socket
import subprocess
import sys
import threading
import traceback
import uuid
import webbrowser
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

import rutas
from rutas import WEB
import catalogo
import recorte
from registro import ESTADOS_IMAGEN, ESTADOS_VIDEO, Registro, escribir_atomico, filtrar

CLAVE = re.compile(r"^[a-z0-9_]{1,80}$")
VISTAS = ("original", "conectividad", "rembg", "juego", "final", "poster", "previa")
PRIMER_PUERTO = 8811
MAX_SUBIDA = 400 * 1024 * 1024
CARPETAS_VIDEO = tuple(catalogo.CARPETAS_DE_VIDEO)


class Problema(Exception):
    def __init__(self, codigo: int, mensaje: str, **extra):
        super().__init__(mensaje)
        self.codigo, self.mensaje, self.extra = codigo, mensaje, extra


# ---------- trabajos en segundo plano ----------
class Trabajos:
    """Lo que tarda (rembg, un video, aplicar) corre en un hilo; la pagina pregunta."""

    def __init__(self):
        self.todos: dict[str, dict] = {}
        self.candado = threading.Lock()
        self.cola_rembg = threading.Semaphore(1)
        self.cola_video = threading.Semaphore(1)

    def lanzar(self, tipo: str, clave: str, funcion, semaforo=None) -> dict:
        with self.candado:
            for t in self.todos.values():
                if t["tipo"] == tipo and t["clave"] == clave and t["estado"] in ("en cola", "corriendo"):
                    return t
            trabajo = {"id": uuid.uuid4().hex[:12], "tipo": tipo, "clave": clave, "estado": "en cola",
                       "progreso": 0.0, "mensaje": "", "resultado": None, "error": None}
            self.todos[trabajo["id"]] = trabajo

        def correr():
            with (semaforo or threading.Semaphore(1)):
                trabajo["estado"] = "corriendo"
                try:
                    trabajo["resultado"] = funcion(trabajo)
                    trabajo["estado"] = "listo"
                    trabajo["progreso"] = 1.0
                except Exception as error:  # se muestra en la pagina
                    traceback.print_exc()
                    trabajo["estado"] = "fallo"
                    trabajo["error"] = str(error) or error.__class__.__name__

        threading.Thread(target=correr, daemon=True).start()
        return trabajo

    def activo(self, tipo: str, clave: str) -> dict | None:
        with self.candado:
            return next((t for t in self.todos.values() if t["tipo"] == tipo and t["clave"] == clave
                         and t["estado"] in ("en cola", "corriendo")), None)


# ---------- el estudio ----------
class Estudio:
    def __init__(self):
        self.d = rutas.datos()
        for carpeta in ("trabajos", "importaciones", "cache", "videos", "respaldos"):
            self.d[carpeta].mkdir(parents=True, exist_ok=True)
        self.registro = Registro()
        self.trabajos = Trabajos()
        self.recargar()
        resumen = self.registro.importar_previo()
        print(f"trabajo previo: {resumen['elecciones']} elecciones, {resumen['regenerar']} a regenerar, "
              f"{resumen['islas']} con islas revisadas", flush=True)

    def recargar(self) -> None:
        catalogo.prompts.cache_clear()
        self.registro.sincronizar(catalogo.catalogo())

    # ----- rutas de archivos -----
    @staticmethod
    def firma(ruta: Path) -> str:
        estado = ruta.stat()
        return hashlib.sha1(f"{ruta}|{estado.st_mtime_ns}|{estado.st_size}".encode()).hexdigest()[:10]

    def cache(self, *partes: str) -> Path:
        ruta = self.d["cache"].joinpath(*partes)
        ruta.parent.mkdir(parents=True, exist_ok=True)
        return ruta

    def ruta_corte(self, clave: str, metodo: str) -> Path | None:
        """El PNG del corte (lo calcula si es rapido); None si falta y es rembg."""
        entrada = self.registro.entrada(clave)
        archivos = entrada["archivos"]
        if metodo == "juego":
            return Path(archivos["juego"]) if archivos.get("juego") else None
        original = Path(archivos["original"]) if archivos.get("original") else None
        if original is None or not original.exists():
            return None
        if metodo == "opaco":
            return original
        destino = self.cache("cortes", metodo, f"{clave}.{self.firma(original)}.png")
        if destino.exists():
            return destino
        if metodo == "rembg":
            return None
        rgba = recorte.corte_conectividad(original, clave)
        escribir_atomico(destino, recorte.png(rgba))
        return destino

    def calcular_rembg(self, clave: str) -> dict:
        original = Path(self.registro.entrada(clave)["archivos"]["original"])
        destino = self.cache("cortes", "rembg", f"{clave}.{self.firma(original)}.png")

        def trabajo(t):
            if destino.exists():
                return {"ruta": str(destino)}
            t["mensaje"] = "Cargando el modelo y recortando…"
            t["progreso"] = 0.2
            escribir_atomico(destino, recorte.png(recorte.corte_rembg(original)))
            return {"ruta": str(destino)}

        return self.trabajos.lanzar("rembg", clave, trabajo, self.trabajos.cola_rembg)

    def islas(self, clave: str, metodo: str) -> tuple[dict, Path]:
        corte = self.ruta_corte(clave, metodo)
        if corte is None:
            raise Problema(409, "Ese corte todavía no está calculado.")
        nombre = f"{clave}.{metodo}.{self.firma(corte)}"
        fichas_json, mapa_png = self.cache("islas", nombre + ".json"), self.cache("islas", nombre + ".mapa.png")
        if not fichas_json.exists():
            rgba = recorte.cargar_rgba(corte)
            fichas, mapa = recorte.islas_y_mapa(rgba)
            escribir_atomico(mapa_png, mapa)
            datos = {"ancho": int(rgba.shape[1]), "alto": int(rgba.shape[0]), "islas": fichas,
                     "firma": self.firma(corte)}
            escribir_atomico(fichas_json, json.dumps(datos).encode())
        return json.loads(fichas_json.read_text()), mapa_png

    def vista(self, clave: str, vista: str) -> Path | None:
        entrada = self.registro.entrada(clave)
        archivos = entrada["archivos"]
        if vista in ("conectividad", "rembg", "juego"):
            return self.ruta_corte(clave, vista)
        if vista == "previa":
            previa = (entrada.get("marcas_previas") or {}).get("limpia")
            return Path(previa) if previa else None
        ruta = archivos.get(vista)
        return Path(ruta) if ruta else None

    def miniatura(self, clave: str) -> bytes:
        entrada = self.registro.entrada(clave)
        archivos = entrada["archivos"]
        fuente = next((Path(r) for r in (archivos.get("final"), archivos.get("juego"),
                                          archivos.get("poster"), archivos.get("original"))
                       if r and Path(r).exists()), None)
        if fuente is None and entrada.get("video"):
            fuente = self.cuadro_de_video(entrada["video"])
        if fuente is None:
            raise Problema(404, "sin imagen")
        destino = self.cache("miniaturas", f"{clave}.{self.firma(fuente)}.png")
        if not destino.exists():
            escribir_atomico(destino, recorte.miniatura(fuente))
        return destino.read_bytes()

    def cuadro_de_video(self, video: dict) -> Path | None:
        fuente = next((Path(r) for r in (video.get("master"), video.get("mov")) if r and Path(r).exists()), None)
        if fuente is None:
            return None
        destino = self.cache("cuadros", f"{video['archivo_mov']}.{self.firma(fuente)}.png")
        if not destino.exists():
            subprocess.run(["ffmpeg", "-v", "error", "-ss", "1", "-i", str(fuente), "-frames:v", "1",
                            "-y", str(destino)], check=False, capture_output=True)
        return destino if destino.exists() else None

    # ----- acciones -----
    def guardar(self, clave: str, pedido: dict) -> dict:
        entrada = self.registro.entrada(clave)
        metodo = pedido.get("corte") or (entrada.get("recorte") or {}).get("metodo")
        if metodo not in ("conectividad", "rembg", "juego", "opaco"):
            raise Problema(400, "Primero elegí el fondo (paso 1).")
        corte = self.ruta_corte(clave, metodo)
        if corte is None:
            raise Problema(409, "Ese corte todavía no está calculado.")
        rojas = [str(r) for r in pedido.get("rojas", []) if re.fullmatch(r"[sh][0-9]+", str(r))]
        verdes = [str(r) for r in pedido.get("verdes", []) if re.fullmatch(r"[sh][0-9]+", str(r))]
        trazos = limpiar_trazos(pedido.get("trazos", []))
        rgba = recorte.cargar_rgba(corte)
        final = rgba if metodo == "opaco" else recorte.renderizar(rgba, rojas, trazos)
        carpeta = self.d["trabajos"] / clave
        escribir_atomico(carpeta / "final.png", recorte.png(final))
        marcas = {"corte": metodo, "rojas": sorted(set(rojas)), "verdes": sorted(set(verdes)),
                  "trazos": trazos, "firma_corte": self.firma(corte), "corte_ruta": str(corte)}
        escribir_atomico(carpeta / "marcas.json", json.dumps(marcas, ensure_ascii=False, indent=2).encode())
        return self.registro.guardar_trabajo(clave, marcas, carpeta / "final.png")

    def previa(self, clave: str, pedido: dict) -> bytes:
        metodo = pedido.get("corte")
        corte = self.ruta_corte(clave, metodo) if metodo else None
        if corte is None:
            raise Problema(409, "Ese corte todavía no está calculado.")
        rgba = recorte.cargar_rgba(corte)
        if metodo == "opaco":
            return recorte.png(rgba)
        rojas = [str(r) for r in pedido.get("rojas", []) if re.fullmatch(r"[sh][0-9]+", str(r))]
        return recorte.png(recorte.renderizar(rgba, rojas, limpiar_trazos(pedido.get("trazos", []))))

    def procesar_video(self, clave: str, menores: int) -> dict:
        import video as estudio_video

        entrada = self.registro.copia(clave)
        if not entrada.get("video") or not entrada["video"].get("master"):
            raise Problema(400, "Este asset no tiene master de video para procesar.")

        def trabajo(t):
            def progreso(hechos, total):
                t["progreso"] = hechos / total if total else 0.5
                t["mensaje"] = f"cuadro {hechos} de {total}" if total else "codificando…"

            t["mensaje"] = "Arrancando ffmpeg…"
            mov, opciones = estudio_video.procesar(entrada["video"], self.d["videos"], menores, progreso)
            self.registro.video_procesado(clave, mov, opciones)
            return {"mov": str(mov), **opciones}

        return self.trabajos.lanzar("video", clave, trabajo, self.trabajos.cola_video)

    def importar(self, clave: str, nombre: str, cuerpo: bytes, reemplazar: bool, carpeta: str | None) -> dict:
        if not CLAVE.match(clave):
            raise Problema(400, "El nombre tiene que ser en minúsculas, con _ (por ejemplo cartonero__vaquero).")
        if cuerpo[:8] == b"\x89PNG\r\n\x1a\n" or cuerpo[:3] == b"\xff\xd8\xff":
            return self.importar_imagen(clave, ".png" if cuerpo[:1] == b"\x89" else ".jpg", cuerpo)
        if cuerpo[4:8] == b"ftyp":
            return self.importar_video(clave, cuerpo, reemplazar, carpeta)
        raise Problema(400, f"«{nombre}» no es un PNG, un JPG ni un MP4.")

    def importar_imagen(self, clave: str, extension: str, cuerpo: bytes) -> dict:
        from PIL import Image

        try:
            with Image.open(io.BytesIO(cuerpo)) as prueba:
                prueba.verify()
        except Exception as error:
            raise Problema(400, f"La imagen no se puede abrir: {error}")
        carpeta = self.d["importaciones"]
        for vieja in carpeta.glob(f"{clave}.*"):
            respaldo = self.d["respaldos"] / "importaciones" / f"{clave}.{datetime.now():%Y%m%d-%H%M%S}{vieja.suffix}"
            respaldo.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(vieja, respaldo)
        destino = carpeta / f"{clave}{extension}"
        escribir_atomico(destino, cuerpo)
        with self.registro.candado:
            if clave not in self.registro.assets:
                self.registro.nueva_importada(ficha_importada(clave, self.registro.assets))
            entrada = self.registro.entrada(clave)
            entrada["origen"] = entrada.get("origen") or "importado"
            entrada["archivos"]["original"] = str(destino)
            entrada["marcas"] = None
            entrada["recorte"] = {"metodo": "opaco" if entrada["tipo"] == "fondo" else None, "origen": None}
            entrada["imagen"]["estado"] = "sin revisar"
            self.registro._tocar(entrada, f"imagen nueva importada ({destino.name})")
            self.registro.guardar()
        if entrada["tipo"] != "fondo":
            self.ruta_corte(clave, "conectividad")
            self.calcular_rembg(clave)
        return self.registro.copia(clave)

    def importar_video(self, clave: str, cuerpo: bytes, reemplazar: bool, carpeta: str | None) -> dict:
        carpeta = carpeta or carpeta_de_video(clave, self.registro.assets)
        if carpeta not in CARPETAS_VIDEO:
            raise Problema(400, "¿De qué clase es este video? Elegila en la lista.", pedir_carpeta=True)
        nombre = clave
        kind = catalogo.CARPETAS_DE_VIDEO[carpeta]
        if kind == "fondo" and not clave.startswith("bg_"):
            nombre = "bg_" + clave
        destino = self.d["generador"] / "video" / carpeta / f"{nombre}.mp4"
        if destino.exists() and not reemplazar:
            raise Problema(409, f"Ya hay un video {carpeta}/{destino.name}. ¿Lo reemplazo?", existe=True)
        if destino.exists():
            respaldo = self.d["respaldos"] / "videos" / carpeta / f"{nombre}.{datetime.now():%Y%m%d-%H%M%S}.mp4"
            respaldo.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(destino, respaldo)
        destino.parent.mkdir(parents=True, exist_ok=True)
        escribir_atomico(destino, cuerpo)
        self.recargar()
        objetivo = next((c for c, e in self.registro.assets.items()
                         if e.get("video") and e["video"].get("master") == str(destino)), None)
        if objetivo is None:
            raise Problema(500, "El video se guardó pero no encontré su ficha.")
        with self.registro.candado:
            entrada = self.registro.entrada(objetivo)
            entrada["video"].update({"estado": "sin revisar", "tocado": True, "mov_estudio": None,
                                     "procesado": None})
            self.registro._tocar(entrada, f"video nuevo importado ({carpeta}/{destino.name})")
            self.registro.guardar()
        return self.registro.copia(objetivo)

    def resumen(self, entrada: dict) -> dict:
        video = entrada.get("video") or {}
        return {
            "id": entrada["id"], "nombre": entrada["nombre"], "tipo": entrada["tipo"],
            "personaje": entrada["personaje"], "tipo_skin": entrada["tipo_skin"], "atlas": entrada["atlas"],
            "estado_imagen": entrada["imagen"]["estado"], "nota_imagen": entrada["imagen"].get("nota", ""),
            "estado_video": video.get("estado", "sin video"),
            "nota_video": video.get("nota", "") if video.get("tocado") else "",
            "metodo": (entrada.get("recorte") or {}).get("metodo"),
            "solo_video": bool(entrada.get("solo_video")), "origen": entrada.get("origen"),
            "guardado": entrada["fechas"].get("guardado"),
        }


def limpiar_trazos(trazos) -> list[dict]:
    limpios = []
    for t in (trazos or [])[: recorte.MAX_TRAZOS]:
        try:
            puntos = [[round(float(x), 1), round(float(y), 1)] for x, y in t.get("puntos", [])][:recorte.MAX_PUNTOS]
            radio = max(0.5, min(400.0, float(t.get("radio", 8))))
        except (TypeError, ValueError):
            continue
        if puntos:
            limpios.append({"modo": "goma" if t.get("modo") == "goma" else "pincel", "radio": radio,
                            "puntos": puntos})
    return limpios


def ficha_importada(clave: str, assets: dict) -> dict:
    """La ficha de un asset que el juego todavia no tiene: lo que se deduce del nombre."""
    base, _, skin = clave.partition("__")
    tipo = catalogo.tipo_de(clave, "", catalogo.prompts().get(clave, {}).get("category"))
    hermano = assets.get(base) or next((e for e in assets.values() if e["personaje"] == base and e["atlas"]), None)
    atlas = f"fam_{skin}" if skin in catalogo.FAMILIAS else (hermano or {}).get("atlas", "")
    nombre = catalogo.nombre_de_personaje(catalogo.personaje_de(clave)) or clave
    return {
        "id": clave, "nombre": nombre + (f" — {catalogo.nombre_de_skin(skin)}" if skin else ""),
        "tipo": tipo, "personaje": catalogo.personaje_de(clave) if tipo != "UI" else "",
        "tipo_skin": catalogo.tipo_de_skin(clave) if tipo in ("skin", "personaje base") else "",
        "atlas": atlas, "sprite": "", "categoria": "skinfam" if skin in catalogo.FAMILIAS else
        ("skin" if skin else "character"), "en_prompts": clave in catalogo.prompts(), "solo_video": False,
        "origen": "importado",
    }


def carpeta_de_video(clave: str, assets: dict) -> str | None:
    if clave.endswith(("_talk", "_action")) or re.search(r"_(talk|action)_v[0-9]+$", clave):
        return "visitantes"
    if clave.startswith("bg_"):
        return "fondos"
    if clave.startswith("npc_"):
        return "loops"
    entrada = assets.get(re.sub(r"_v[0-9]+$", "", clave))
    if entrada and entrada["tipo"] in ("personaje base", "visitante/especial"):
        return "personajes"
    return None


# ---------- HTTP ----------
class Manejador(BaseHTTPRequestHandler):
    estudio: Estudio = None
    protocol_version = "HTTP/1.1"

    def log_message(self, formato, *args):
        if self.command != "GET" or "/api/trabajo" not in self.path:
            sys.stderr.write(f"[{datetime.now():%H:%M:%S}] {formato % args}\n")

    # ----- respuestas -----
    def json(self, codigo: int, cuerpo) -> None:
        datos = json.dumps(cuerpo, ensure_ascii=False).encode()
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(datos)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(datos)

    def bytes_(self, datos: bytes, tipo: str, cache: bool = False) -> None:
        self.send_response(200)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(datos)))
        self.send_header("Cache-Control", "max-age=3600" if cache else "no-store")
        self.end_headers()
        self.wfile.write(datos)

    def archivo(self, ruta: Path, tipo: str | None = None) -> None:
        """Un archivo, con Range: Safari no reproduce un video sin pedidos parciales."""
        if not ruta or not ruta.exists():
            raise Problema(404, "no existe")
        tipo = tipo or mimetypes.guess_type(ruta.name)[0] or "application/octet-stream"
        if ruta.suffix == ".mov":
            tipo = "video/quicktime"
        total = ruta.stat().st_size
        desde, hasta = 0, total - 1
        rango = self.headers.get("Range")
        parcial = False
        if rango and (m := re.match(r"bytes=(\d*)-(\d*)$", rango.strip())):
            if m[1]:
                desde = int(m[1])
                hasta = int(m[2]) if m[2] else total - 1
            elif m[2]:
                desde = max(0, total - int(m[2]))
            hasta = min(hasta, total - 1)
            if desde > hasta:
                self.send_response(416)
                self.send_header("Content-Range", f"bytes */{total}")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            parcial = True
        largo = hasta - desde + 1
        self.send_response(206 if parcial else 200)
        self.send_header("Content-Type", tipo)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(largo))
        self.send_header("Cache-Control", "no-store")
        if parcial:
            self.send_header("Content-Range", f"bytes {desde}-{hasta}/{total}")
        self.end_headers()
        if self.command == "HEAD":
            return
        with open(ruta, "rb") as f:
            f.seek(desde)
            restante = largo
            while restante > 0:
                bloque = f.read(min(1 << 20, restante))
                if not bloque:
                    break
                try:
                    self.wfile.write(bloque)
                except (BrokenPipeError, ConnectionResetError):
                    return
                restante -= len(bloque)

    def cuerpo(self) -> bytes:
        largo = int(self.headers.get("Content-Length") or 0)
        if largo > MAX_SUBIDA:
            raise Problema(413, "El archivo es demasiado grande.")
        return self.rfile.read(largo) if largo else b""

    def pedido_json(self) -> dict:
        crudo = self.cuerpo()
        try:
            return json.loads(crudo) if crudo else {}
        except json.JSONDecodeError:
            raise Problema(400, "pedido ilegible")

    # ----- ruteo -----
    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        self.atender(self.rutas_get)

    def do_POST(self):
        self.atender(self.rutas_post)

    def atender(self, rutas_) -> None:
        url = urlparse(self.path)
        partes = [unquote(p) for p in url.path.strip("/").split("/") if p]
        query = {k: v[-1] for k, v in parse_qs(url.query).items()}
        try:
            rutas_(partes, query)
        except Problema as p:
            self.json(p.codigo, {"error": p.mensaje, **p.extra})
        except KeyError as error:
            self.json(404, {"error": f"no existe: {error}"})
        except ValueError as error:
            self.json(400, {"error": str(error)})
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as error:
            traceback.print_exc()
            self.json(500, {"error": f"{error.__class__.__name__}: {error}"})

    def clave(self, partes: list[str], indice: int = 2) -> str:
        if len(partes) <= indice or not CLAVE.match(partes[indice]):
            raise Problema(400, "falta el asset")
        clave = partes[indice]
        self.estudio.registro.entrada(clave)
        return clave

    def rutas_get(self, partes: list[str], query: dict) -> None:
        e = self.estudio
        if not partes:
            return self.archivo(WEB / "index.html", "text/html; charset=utf-8")
        if partes[0] == "web" and len(partes) == 2 and re.fullmatch(r"[a-z0-9_.-]+", partes[1]):
            return self.archivo(WEB / partes[1])
        if partes[0] != "api":
            raise Problema(404, "no existe")
        accion = partes[1] if len(partes) > 1 else ""
        if accion == "assets":
            with e.registro.candado:
                todos = [e.resumen(a) for a in e.registro.assets.values()]
            # Los filtros por URL usan los mismos nombres que la pagina.
            elegidos = filtrar([e.registro.assets[a["id"]] for a in todos], query)
            ids = {a["id"] for a in elegidos}
            return self.json(200, {"assets": [a for a in todos if a["id"] in ids], "total": len(todos),
                                   "estados_imagen": ESTADOS_IMAGEN, "estados_video": ESTADOS_VIDEO,
                                   "tipos": catalogo.TIPOS, "tipos_skin": catalogo.TIPOS_DE_SKIN,
                                   "carpetas_video": CARPETAS_VIDEO,
                                   "importado_previo": e.registro.datos.get("importado_previo")})
        if accion == "asset":
            clave = self.clave(partes)
            entrada = e.registro.copia(clave)
            cortes = {}
            for metodo in ("conectividad", "rembg", "juego", "opaco"):
                try:
                    cortes[metodo] = e.ruta_corte(clave, metodo) is not None if metodo != "conectividad" \
                        else bool(entrada["archivos"].get("original"))
                except Exception:
                    cortes[metodo] = False
            trabajo = e.trabajos.activo("rembg", clave)
            entrada["cortes_disponibles"] = cortes
            entrada["trabajo_rembg"] = trabajo
            entrada["trabajo_video"] = e.trabajos.activo("video", clave)
            return self.json(200, entrada)
        if accion == "imagen":
            clave = self.clave(partes)
            vista = query.get("vista", "juego")
            if vista not in VISTAS:
                raise Problema(400, "vista desconocida")
            if vista == "rembg" and e.ruta_corte(clave, "rembg") is None:
                if not e.registro.entrada(clave)["archivos"].get("original"):
                    raise Problema(404, "sin original")
                return self.json(202, {"trabajo": e.calcular_rembg(clave)})
            return self.archivo(e.vista(clave, vista))
        if accion == "miniatura":
            return self.bytes_(e.miniatura(self.clave(partes)), "image/png", cache=True)
        if accion == "islas":
            datos, _ = e.islas(self.clave(partes), query.get("corte", ""))
            return self.json(200, datos)
        if accion == "mapa":
            _, mapa = e.islas(self.clave(partes), query.get("corte", ""))
            return self.archivo(mapa, "image/png")
        if accion == "video":
            clave = self.clave(partes)
            video = e.registro.entrada(clave).get("video") or {}
            cual = {"juego": video.get("mov"), "master": video.get("master"),
                    "estudio": video.get("mov_estudio")}.get(query.get("cual", "juego"))
            return self.archivo(Path(cual) if cual else None)
        if accion == "trabajo" and len(partes) == 3:
            trabajo = e.trabajos.todos.get(partes[2])
            if trabajo is None:
                raise Problema(404, "no existe ese trabajo")
            return self.json(200, trabajo)
        if accion == "aplicar":
            import aplicar

            plan = aplicar.plan(e.registro)
            return self.json(200, {"plan": plan, "trabajo": e.trabajos.activo("aplicar", "todo"),
                                   "informe": aplicar.ejecutar(plan, dry_run=True)})
        raise Problema(404, "no existe")

    def rutas_post(self, partes: list[str], query: dict) -> None:
        e = self.estudio
        if len(partes) < 2 or partes[0] != "api":
            raise Problema(404, "no existe")
        accion = partes[1]
        if accion == "importar":
            cuerpo = self.cuerpo()
            entrada = e.importar(query.get("id", ""), query.get("nombre", "archivo"), cuerpo,
                                 query.get("reemplazar") == "1", query.get("carpeta") or None)
            return self.json(200, entrada)
        if accion == "aplicar":
            import aplicar

            pedido = self.pedido_json()
            if not pedido.get("confirmar"):
                raise Problema(400, "falta confirmar")

            def trabajo(t):
                def avisar(texto):
                    t["mensaje"] = texto
                return aplicar.en_rama(e.registro, avisar)

            return self.json(200, {"trabajo": e.trabajos.lanzar("aplicar", "todo", trabajo)})
        if accion == "recargar":
            e.recargar()
            return self.json(200, {"ok": True})
        clave = self.clave(partes)
        pedido = self.pedido_json()
        if accion == "elegir":
            return self.json(200, e.registro.elegir_corte(clave, pedido.get("metodo")))
        if accion == "guardar":
            return self.json(200, e.guardar(clave, pedido))
        if accion == "previa":
            return self.bytes_(e.previa(clave, pedido), "image/png")
        if accion == "estado-imagen":
            return self.json(200, e.registro.estado_imagen(clave, pedido.get("estado", ""), pedido.get("nota")))
        if accion == "estado-video":
            return self.json(200, e.registro.estado_video(clave, pedido.get("estado", ""), pedido.get("nota")))
        if accion == "rembg":
            return self.json(200, {"trabajo": e.calcular_rembg(clave)})
        if accion == "procesar-video":
            menores = max(0, min(100000, int(pedido.get("menores") or 0)))
            return self.json(200, {"trabajo": e.procesar_video(clave, menores)})
        raise Problema(404, "no existe")


def puerto_libre(desde: int) -> int:
    for puerto in range(desde, desde + 40):
        with socket.socket() as prueba:
            if prueba.connect_ex(("127.0.0.1", puerto)) != 0:
                return puerto
    raise SystemExit("No encontré un puerto libre.")


def abrir_navegador(direccion: str) -> None:
    """Safari: es el que muestra la transparencia de los videos HEVC."""
    if sys.platform == "darwin" and subprocess.run(["open", "-a", "Safari", direccion]).returncode == 0:
        return
    webbrowser.open(direccion)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--puerto", type=int, default=0)
    parser.add_argument("--no-abrir", action="store_true")
    args = parser.parse_args()

    print("Armando el catálogo del juego…", flush=True)
    Manejador.estudio = Estudio()
    puerto = args.puerto or puerto_libre(PRIMER_PUERTO)
    servidor = ThreadingHTTPServer(("127.0.0.1", puerto), Manejador)
    servidor.daemon_threads = True
    direccion = f"http://127.0.0.1:{puerto}/"
    print(f"\nEstudio de assets abierto en {direccion}")
    print("Dejá esta ventana abierta mientras trabajás. Para terminar: cerrala (o Ctrl+C).", flush=True)
    if not args.no_abrir:
        threading.Timer(0.6, abrir_navegador, args=(direccion,)).start()
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        servidor.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
