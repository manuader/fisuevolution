"""El registro central: una entrada por asset, con todo lo que el dueno decidio.

Vive en `~/Desktop/estudio-assets/registro.json` (fuera del repo: sobrevive a
cambiar de rama). Lo que sale del juego —tipo, atlas, archivos, video— se rehace
desde el catalogo en cada arranque; lo del dueno —estados, notas, marcas, el
recorte elegido— no se toca nunca al sincronizar.

Dos archivos de afuera se mantienen al dia desde aca:

- `regenerar-desde-estudio.json` del generador: la lista de todo lo que esta a
  regenerar (imagen o video) con su nota. Se reescribe entera en cada cambio, asi
  que siempre es el estado actual, no un historial.
- `video/revision.json` del generador: el estado de cada video (va / regenerar /
  obviar). Se cambian solo `estado` y `nota` de la clave tocada; el resto del
  archivo queda como estaba. La primera vez se respalda el original.

Todas las escrituras son atomicas (temporal + fsync + rename): un corte de luz
deja el archivo viejo o el nuevo, nunca uno a medias.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
import shutil
import threading
from datetime import datetime
from pathlib import Path

import rutas

ESTADOS_IMAGEN = ("sin revisar", "listo", "refinar", "ninguno sirve", "regenerar", "sin imagen")
ESTADOS_VIDEO = ("sin video", "sin revisar", "va", "regenerar", "obviar")
METODOS = ("conectividad", "rembg", "juego", "opaco")
VERSION = 1

# Lo que el catalogo pisa en cada arranque. Todo lo demas es del dueno.
DEL_CATALOGO = ("nombre", "tipo", "personaje", "tipo_skin", "atlas", "sprite", "categoria",
                "en_prompts", "solo_video")


def ahora() -> str:
    return datetime.now().isoformat(timespec="seconds")


def escribir_atomico(ruta: Path, datos: bytes) -> None:
    ruta.parent.mkdir(parents=True, exist_ok=True)
    temporal = ruta.with_name(f".{ruta.name}.{os.getpid()}.tmp")
    with open(temporal, "wb") as f:
        f.write(datos)
        f.flush()
        os.fsync(f.fileno())
    os.replace(temporal, ruta)


def escribir_json(ruta: Path, datos) -> None:
    texto = json.dumps(datos, ensure_ascii=False, indent=2) + "\n"
    escribir_atomico(ruta, texto.encode("utf-8"))


def huella(ruta: str | Path | None) -> str | None:
    if not ruta or not Path(ruta).exists():
        return None
    return hashlib.sha1(Path(ruta).read_bytes()).hexdigest()


def entrada_nueva(ficha: dict) -> dict:
    solo_video = bool(ficha.get("solo_video"))
    video = ficha.get("video")
    entrada = {
        "id": ficha["id"],
        **{campo: ficha.get(campo) for campo in DEL_CATALOGO},
        "origen": ficha.get("origen", "juego"),
        "archivos": {"original": None, "juego": None, "poster": None, "final": None, "cortes": {}},
        "video": None,
        "recorte": {"metodo": None, "origen": None},
        "marcas": None,
        "marcas_previas": None,
        "imagen": {"estado": "sin imagen" if solo_video else "sin revisar", "nota": ""},
        "aplicado": {"imagen": None, "video": None},
        "en_juego": False,
        "fechas": {"creado": ahora(), "actualizado": ahora(), "guardado": None},
        "historial": [],
    }
    if ficha.get("tipo") == "fondo" and not solo_video:
        entrada["recorte"] = {"metodo": "opaco", "origen": "estudio"}
    if video:
        entrada["video"] = {"estado": "sin revisar", "nota": "", "mov_estudio": None, "procesado": None}
    return entrada


def _pegar_video(entrada: dict, video: dict | None) -> None:
    """Los datos del catalogo del video, sin pisar el estado y la nota del dueno."""
    if video is None:
        if entrada["video"] and not entrada["video"].get("master") and not entrada["video"].get("mov_estudio"):
            entrada["video"] = None
        return
    propio = entrada["video"] or {"estado": "sin revisar", "nota": "", "mov_estudio": None, "procesado": None}
    propio.update({k: v for k, v in video.items() if k != "revision"})
    entrada["video"] = propio


class Registro:
    """El registro en memoria, con un candado: el servidor atiende en varios hilos."""

    def __init__(self, ruta: Path | None = None):
        self.d = rutas.datos()
        self.ruta = ruta or self.d["registro"]
        self.candado = threading.RLock()
        if self.ruta.exists():
            self.datos = json.loads(self.ruta.read_text(encoding="utf-8"))
        else:
            self.datos = {"version": VERSION, "creado": ahora(), "importado_previo": None, "assets": {}}

    # ---------- lectura ----------
    @property
    def assets(self) -> dict[str, dict]:
        return self.datos["assets"]

    def entrada(self, clave: str) -> dict:
        if clave not in self.assets:
            raise KeyError(clave)
        return self.assets[clave]

    def copia(self, clave: str) -> dict:
        with self.candado:
            return copy.deepcopy(self.entrada(clave))

    # ---------- escritura ----------
    def guardar(self) -> None:
        with self.candado:
            escribir_json(self.ruta, self.datos)

    def _tocar(self, entrada: dict, que: str) -> None:
        entrada["fechas"]["actualizado"] = ahora()
        entrada["historial"].append({"fecha": ahora(), "que": que})
        del entrada["historial"][:-50]

    def sincronizar(self, catalogo: dict[str, dict]) -> None:
        """Mete lo nuevo del catalogo y le refresca a todo lo que viene del juego."""
        with self.candado:
            for clave, ficha in catalogo.items():
                entrada = self.assets.get(clave)
                if entrada is None:
                    entrada = self.assets[clave] = entrada_nueva(ficha)
                for campo in DEL_CATALOGO:
                    entrada[campo] = ficha.get(campo)
                if entrada.get("origen") != "importado" or ficha["archivos"].get("original"):
                    entrada["archivos"]["original"] = ficha["archivos"].get("original")
                entrada["archivos"]["juego"] = ficha["archivos"].get("juego")
                entrada["archivos"]["poster"] = ficha["archivos"].get("poster")
                _pegar_video(entrada, ficha.get("video"))
                # Mientras el dueno no lo toque aca, el estado del video es el de
                # `revision.json` (que tambien se edita del lado del generador).
                if entrada["video"] and (ficha.get("video") or {}).get("revision") \
                        and not entrada["video"].get("tocado"):
                    previo = ficha["video"]["revision"]
                    if previo.get("estado") in ESTADOS_VIDEO:
                        entrada["video"]["estado"] = previo["estado"]
                        entrada["video"]["nota"] = previo.get("nota", "")
            self.guardar()

    def importar_previo(self) -> dict:
        """Una sola vez: las elecciones de recorte, los 4 a regenerar y las islas
        ya revisadas pasan al registro como estado inicial. Se archiva una copia."""
        with self.candado:
            if self.datos.get("importado_previo"):
                return self.datos["importado_previo"]
            resumen = {"fecha": ahora(), "elecciones": 0, "regenerar": 0, "islas": 0, "faltan": []}
            archivo = self.d["base"] / "importado-previo"
            decisiones_json = self.d["previo_decisiones"]
            if decisiones_json.exists():
                (archivo / "revision-v2").mkdir(parents=True, exist_ok=True)
                shutil.copy2(decisiones_json, archivo / "revision-v2" / decisiones_json.name)
                decisiones = json.loads(decisiones_json.read_text())
                for clave, metodo in sorted(decisiones.get("elecciones", {}).items()):
                    entrada = self.assets.get(clave)
                    if entrada is None or metodo not in METODOS:
                        resumen["faltan"].append(clave)
                        continue
                    entrada["recorte"] = {"metodo": metodo, "origen": "revision-v2"}
                    entrada["en_juego"] = True
                    self._tocar(entrada, f"corte «{metodo}» elegido en la revisión de recortes (ya está en el juego)")
                    resumen["elecciones"] += 1
                for clave in decisiones.get("regenerar", []):
                    entrada = self.assets.get(clave)
                    if entrada is None:
                        resumen["faltan"].append(clave)
                        continue
                    entrada["imagen"] = {"estado": "regenerar",
                                         "nota": "Marcado para regenerar en la revisión de recortes: ningún recorte servía."}
                    self._tocar(entrada, "marcado para regenerar en la revisión de recortes")
                    resumen["regenerar"] += 1

            islas = self.d["previo_islas"]
            marcas_json = islas / "marcas.json"
            if marcas_json.exists():
                destino = archivo / "islas-review"
                destino.mkdir(parents=True, exist_ok=True)
                shutil.copy2(marcas_json, destino / "marcas.json")
                if (islas / "limpias").exists():
                    shutil.copytree(islas / "limpias", destino / "limpias", dirs_exist_ok=True)
                for clave, marca in sorted(json.loads(marcas_json.read_text()).items()):
                    entrada = self.assets.get(clave)
                    if entrada is None:
                        resumen["faltan"].append(clave)
                        continue
                    limpia = destino / "limpias" / f"{clave}.png"
                    entrada["marcas_previas"] = {**marca, "limpia": str(limpia) if limpia.exists() else None}
                    if marca.get("listo") and entrada["imagen"]["estado"] != "regenerar":
                        entrada["imagen"]["estado"] = "listo"
                        entrada["en_juego"] = True
                        entrada["fechas"]["guardado"] = marca.get("guardado")
                    self._tocar(entrada, f"islas revisadas en el balde ({len(marca.get('rojas', []))} sacadas; ya en el juego)")
                    resumen["islas"] += 1
            self.datos["importado_previo"] = resumen
            self.guardar()
            self.escribir_pedido_regenerar()
            return resumen

    # ---------- acciones del dueno ----------
    def elegir_corte(self, clave: str, metodo: str | None) -> dict:
        with self.candado:
            entrada = self.entrada(clave)
            if metodo == "ninguno":
                entrada["imagen"]["estado"] = "ninguno sirve"
                self._tocar(entrada, "ningún recorte sirve")
            else:
                if metodo not in METODOS:
                    raise ValueError(f"recorte desconocido: {metodo}")
                entrada["recorte"] = {"metodo": metodo, "origen": "estudio"}
                if entrada["imagen"]["estado"] == "ninguno sirve":
                    entrada["imagen"]["estado"] = "sin revisar"
                self._tocar(entrada, f"corte elegido: {metodo}")
            self.guardar()
            self.escribir_pedido_regenerar()
            return copy.deepcopy(entrada)

    def guardar_trabajo(self, clave: str, marcas: dict, final: Path) -> dict:
        with self.candado:
            entrada = self.entrada(clave)
            entrada["marcas"] = marcas
            entrada["recorte"] = {"metodo": marcas["corte"], "origen": "estudio"}
            entrada["archivos"]["final"] = str(final)
            entrada["imagen"]["estado"] = "listo"
            entrada["fechas"]["guardado"] = ahora()
            self._tocar(entrada, f"guardado ({len(marcas.get('rojas', []))} islas fuera, "
                                 f"{len(marcas.get('trazos', []))} trazos)")
            self.guardar()
            self.escribir_pedido_regenerar()
            return copy.deepcopy(entrada)

    def estado_imagen(self, clave: str, estado: str, nota: str | None = None) -> dict:
        if estado not in ESTADOS_IMAGEN:
            raise ValueError(f"estado de imagen desconocido: {estado}")
        with self.candado:
            entrada = self.entrada(clave)
            entrada["imagen"]["estado"] = estado
            if nota is not None:
                entrada["imagen"]["nota"] = nota.strip()
            entrada["imagen"]["fecha"] = ahora()
            self._tocar(entrada, f"imagen: {estado}" + (f" — {nota.strip()}" if nota else ""))
            self.guardar()
            self.escribir_pedido_regenerar()
            return copy.deepcopy(entrada)

    def estado_video(self, clave: str, estado: str, nota: str | None = None) -> dict:
        if estado not in ESTADOS_VIDEO:
            raise ValueError(f"estado de video desconocido: {estado}")
        with self.candado:
            entrada = self.entrada(clave)
            if not entrada["video"]:
                raise ValueError("este asset no tiene video")
            entrada["video"]["estado"] = estado
            entrada["video"]["tocado"] = True
            if nota is not None:
                entrada["video"]["nota"] = nota.strip()
            entrada["video"]["fecha"] = ahora()
            self._tocar(entrada, f"video: {estado}" + (f" — {nota.strip()}" if nota else ""))
            self.guardar()
            self.escribir_pedido_regenerar()
            if estado in ("va", "regenerar", "obviar") and entrada["video"].get("clave_revision"):
                self.sincronizar_revision(entrada["video"]["clave_revision"], estado, entrada["video"]["nota"])
            return copy.deepcopy(entrada)

    def video_procesado(self, clave: str, mov: Path, opciones: dict) -> None:
        with self.candado:
            entrada = self.entrada(clave)
            entrada["video"]["mov_estudio"] = str(mov)
            entrada["video"]["procesado"] = {"fecha": ahora(), **opciones}
            self._tocar(entrada, "video procesado en el Estudio")
            self.guardar()

    def nueva_importada(self, ficha: dict) -> dict:
        with self.candado:
            entrada = self.assets.get(ficha["id"])
            if entrada is None:
                entrada = self.assets[ficha["id"]] = entrada_nueva({**ficha, "origen": "importado"})
                entrada["origen"] = "importado"
                for campo in DEL_CATALOGO:
                    entrada[campo] = ficha.get(campo)
            return entrada

    def marcar_aplicado(self, claves_imagen: list[str], claves_video: list[str], rama: str) -> None:
        with self.candado:
            for clave in claves_imagen:
                entrada = self.entrada(clave)
                entrada["aplicado"]["imagen"] = {"huella": huella(entrada["archivos"]["final"]),
                                                 "rama": rama, "fecha": ahora()}
                self._tocar(entrada, f"imagen aplicada al juego en {rama}")
            for clave in claves_video:
                entrada = self.entrada(clave)
                entrada["aplicado"]["video"] = {"huella": huella(entrada["video"]["mov_estudio"]),
                                                "rama": rama, "fecha": ahora()}
                self._tocar(entrada, f"video aplicado al juego en {rama}")
            self.guardar()

    # ---------- afuera ----------
    def pedido_regenerar(self) -> list[dict]:
        pedido = []
        for clave, entrada in sorted(self.assets.items()):
            if entrada["imagen"]["estado"] == "regenerar":
                pedido.append({"id": clave, "tipo": "imagen", "nota": entrada["imagen"].get("nota", ""),
                               "fecha": entrada["imagen"].get("fecha") or entrada["fechas"]["actualizado"]})
            video = entrada.get("video")
            if video and video["estado"] == "regenerar":
                pedido.append({"id": clave, "tipo": "video", "nota": video.get("nota", ""),
                               "fecha": video.get("fecha") or entrada["fechas"]["actualizado"],
                               "master": video.get("clave_revision")})
        return pedido

    def escribir_pedido_regenerar(self) -> None:
        ruta = self.d["pedido_regenerar"]
        pedido = self.pedido_regenerar()
        if not ruta.parent.exists():
            return
        anterior = json.loads(ruta.read_text()) if ruta.exists() else None
        nuevo = {"generado_por": "Estudio de assets de FisuEvolution",
                 "explicacion": "Lo que el dueño marcó para regenerar. Se reescribe entero en cada cambio.",
                 "pedidos": pedido}
        if anterior is None and not pedido:
            return
        if anterior and anterior.get("pedidos") == pedido:
            return
        escribir_json(ruta, nuevo)

    def sincronizar_revision(self, clave_revision: str, estado: str, nota: str) -> None:
        ruta = self.d["revision_videos"]
        if not ruta.exists():
            return
        respaldo = self.d["respaldos"] / "revision.antes-del-estudio.json"
        if not respaldo.exists():
            respaldo.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ruta, respaldo)
        revision = json.loads(ruta.read_text(encoding="utf-8"))
        actual = dict(revision.get(clave_revision, {}))
        actual["estado"] = estado
        if nota:
            actual["nota"] = nota
        elif estado != revision.get(clave_revision, {}).get("estado"):
            actual["nota"] = f"marcado «{estado}» en el Estudio de assets ({ahora()[:10]})"
        revision[clave_revision] = actual
        escribir_json(ruta, revision)


def filtrar(assets: list[dict], filtros: dict[str, str]) -> list[dict]:
    """Los filtros de la lista, combinables. Los vacios no filtran."""
    q = (filtros.get("q") or "").strip().lower()

    def pasa(a: dict) -> bool:
        video = a.get("video") or {}
        for campo, valor in (("tipo", a["tipo"]), ("tipo_skin", a["tipo_skin"]),
                             ("personaje", a["personaje"]), ("atlas", a["atlas"]),
                             ("estado_imagen", a["imagen"]["estado"]),
                             ("estado_video", video.get("estado", "sin video"))):
            if filtros.get(campo) and filtros[campo] != valor:
                return False
        if filtros.get("con_notas") in ("1", "true", "si") and not (
                a["imagen"].get("nota") or video.get("nota", "") and video.get("tocado")):
            return False
        if q and q not in f"{a['id']} {a['nombre']}".lower():
            return False
        return True

    return [a for a in assets if pasa(a)]


def exportar(registro: Registro, destino: Path) -> int:
    """Una foto versionable del registro: lo que el dueno decidio, sin rutas de su
    maquina ni historial. Va al repo (`registro.export.json`) para que una sesion
    sin acceso al Escritorio sepa en que quedo cada asset."""
    foto = {}
    for clave, e in sorted(registro.assets.items()):
        video = e.get("video") or {}
        foto[clave] = {
            "tipo": e["tipo"], "personaje": e["personaje"], "tipo_skin": e["tipo_skin"], "atlas": e["atlas"],
            "recorte": (e.get("recorte") or {}).get("metodo"),
            "imagen": e["imagen"]["estado"], "nota_imagen": e["imagen"].get("nota", ""),
            "islas_fuera": len((e.get("marcas") or e.get("marcas_previas") or {}).get("rojas", [])),
            "video": video.get("estado", "sin video"), "nota_video": video.get("nota", "") if video.get("tocado") else "",
            "master": video.get("clave_revision"),
            "aplicado": bool(e.get("en_juego") or (e.get("aplicado") or {}).get("imagen")),
        }
    escribir_json(destino, {"exportado": ahora(), "assets": foto})
    return len(foto)


if __name__ == "__main__":
    import sys

    if sys.argv[1:] != ["--exportar"]:
        raise SystemExit("uso: registro.py --exportar   (escribe Tools/asset-studio/registro.export.json)")
    print(f"exportados: {exportar(Registro(), rutas.EXPORT)} assets → {rutas.EXPORT}")
