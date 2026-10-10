"""El registro: importa el trabajo previo, escribe atomico, y mantiene al dia los
archivos del generador sin pisar lo ajeno. Todo contra carpetas temporales."""

import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import registro as registro_mod  # noqa: E402
from registro import Registro, escribir_json  # noqa: E402

FICHAS = {
    "cartonero": {"id": "cartonero", "nombre": "Cartonero", "tipo": "personaje base", "personaje": "cartonero",
                  "tipo_skin": "base", "atlas": "earth", "sprite": "cartonero_idle", "categoria": "character",
                  "en_prompts": True, "archivos": {"original": None, "juego": None},
                  "video": {"kind": "personaje", "carpeta": "personajes", "id_juego": "cartonero",
                            "clave_revision": "personajes/cartonero", "master": "/x/cartonero.mp4", "mov": None,
                            "archivo_mov": "char_cartonero.mov",
                            "revision": {"estado": "va", "nota": "aprobado"}}},
    "cartonero__oro": {"id": "cartonero__oro", "nombre": "Cartonero — De Oro", "tipo": "skin",
                       "personaje": "cartonero", "tipo_skin": "oro", "atlas": "earth",
                       "sprite": "cartonero_idle__oro", "categoria": "skin", "en_prompts": True,
                       "archivos": {"original": None, "juego": None}, "video": None},
    "senior_doctor": {"id": "senior_doctor", "nombre": "Médico Sr.", "tipo": "personaje base",
                      "personaje": "senior_doctor", "tipo_skin": "base", "atlas": "earth",
                      "sprite": "senior_doctor_idle", "categoria": "character", "en_prompts": True,
                      "archivos": {"original": None, "juego": None}, "video": None},
}


class ConCarpetas(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp)
        self.gen = self.tmp / "generador"
        (self.gen / "video").mkdir(parents=True)
        self.revision = self.gen / "video" / "revision.json"
        escribir_json(self.revision, {
            "personajes/cartonero": {"estado": "va", "nota": "aprobado", "extra": 7},
            "loops/npc_comisario": {"estado": "va", "nota": "de otro"},
        })
        previo = self.tmp / "previo"
        (previo / "islas" / "limpias").mkdir(parents=True)
        escribir_json(previo / "decisiones.json", {
            "elecciones": {"cartonero": "rembg", "cartonero__oro": "conectividad", "fantasma": "rembg"},
            "regenerar": ["senior_doctor"],
        })
        escribir_json(previo / "islas" / "marcas.json", {
            "cartonero__oro": {"rojas": ["s3"], "verdes": [], "origen": "abc", "listo": True,
                               "guardado": "2026-10-10T16:00:00"},
        })
        Image.new("RGBA", (4, 4)).save(previo / "islas" / "limpias" / "cartonero__oro.png")
        entorno = {"ESTUDIO_DATOS": str(self.tmp / "datos"), "ESTUDIO_GENERADOR": str(self.gen),
                   "ESTUDIO_DECISIONES": str(previo / "decisiones.json"), "ESTUDIO_ISLAS": str(previo / "islas")}
        parche = mock.patch.dict(os.environ, entorno)
        parche.start()
        self.addCleanup(parche.stop)

    def nuevo(self) -> Registro:
        r = Registro()
        r.sincronizar(FICHAS)
        return r


class ImportarPrevioTests(ConCarpetas):
    def test_las_elecciones_las_islas_y_los_regenerar_pasan_al_registro(self):
        r = self.nuevo()
        resumen = r.importar_previo()

        self.assertEqual((resumen["elecciones"], resumen["regenerar"], resumen["islas"]), (2, 1, 1))
        self.assertEqual(resumen["faltan"], ["fantasma"])
        self.assertEqual(r.entrada("cartonero")["recorte"], {"metodo": "rembg", "origen": "revision-v2"})
        oro = r.entrada("cartonero__oro")
        self.assertEqual(oro["imagen"]["estado"], "listo")
        self.assertEqual(oro["marcas_previas"]["rojas"], ["s3"])
        self.assertTrue(Path(oro["marcas_previas"]["limpia"]).exists(), "la limpia quedo archivada")
        self.assertEqual(r.entrada("senior_doctor")["imagen"]["estado"], "regenerar")
        self.assertEqual(r.entrada("cartonero")["video"]["estado"], "va", "el estado sale de revision.json")

    def test_se_importa_una_sola_vez_y_sobrevive_a_releer(self):
        r = self.nuevo()
        r.importar_previo()
        r.estado_imagen("cartonero", "refinar", "las manos")

        otra = Registro()
        otra.sincronizar(FICHAS)
        otra.importar_previo()
        self.assertEqual(otra.entrada("cartonero")["imagen"], {**otra.entrada("cartonero")["imagen"],
                                                               "estado": "refinar", "nota": "las manos"})


class EscrituraAtomicaTests(ConCarpetas):
    def test_un_fallo_a_mitad_deja_el_archivo_anterior_entero(self):
        r = self.nuevo()
        antes = r.ruta.read_text()
        with mock.patch.object(registro_mod.os, "replace", side_effect=OSError("se corto la luz")):
            with self.assertRaises(OSError):
                r.estado_imagen("cartonero", "listo")
        self.assertEqual(r.ruta.read_text(), antes)
        json.loads(r.ruta.read_text())

    def test_no_quedan_temporales(self):
        r = self.nuevo()
        r.estado_imagen("cartonero", "refinar", "x")
        sobras = [p.name for p in r.ruta.parent.iterdir() if p.name.endswith(".tmp")]
        self.assertEqual(sobras, [])


class SincronizacionTests(ConCarpetas):
    def test_el_estado_del_video_va_a_revision_sin_pisar_otras_claves(self):
        r = self.nuevo()
        original = self.revision.read_text()

        r.estado_video("cartonero", "regenerar", "que tenga dos manos, no tres")

        revision = json.loads(self.revision.read_text())
        self.assertEqual(revision["personajes/cartonero"],
                         {"estado": "regenerar", "nota": "que tenga dos manos, no tres", "extra": 7})
        self.assertEqual(revision["loops/npc_comisario"], {"estado": "va", "nota": "de otro"})
        respaldo = self.tmp / "datos" / "respaldos" / "revision.antes-del-estudio.json"
        self.assertEqual(respaldo.read_text(), original, "se respaldo antes de la primera escritura")

    def test_una_vez_tocado_aca_manda_el_estudio(self):
        r = self.nuevo()
        r.estado_video("cartonero", "obviar")
        r.sincronizar(FICHAS)  # revision de la ficha sigue diciendo "va"
        self.assertEqual(r.entrada("cartonero")["video"]["estado"], "obviar")

    def test_el_pedido_de_regenerar_lista_imagen_y_video_con_su_nota(self):
        r = self.nuevo()
        r.estado_imagen("cartonero__oro", "regenerar", "pelo castaño")
        r.estado_video("cartonero", "regenerar", "dos manos")

        pedido = json.loads((self.gen / "regenerar-desde-estudio.json").read_text())["pedidos"]
        self.assertEqual([(p["id"], p["tipo"], p["nota"]) for p in pedido],
                         [("cartonero", "video", "dos manos"), ("cartonero__oro", "imagen", "pelo castaño")])
        self.assertTrue(all(p["fecha"] for p in pedido))

        r.estado_imagen("cartonero__oro", "listo")
        pedido = json.loads((self.gen / "regenerar-desde-estudio.json").read_text())["pedidos"]
        self.assertEqual([p["id"] for p in pedido], ["cartonero"], "lo resuelto sale del pedido")

    def test_los_estados_invalidos_se_rechazan(self):
        r = self.nuevo()
        with self.assertRaises(ValueError):
            r.estado_imagen("cartonero", "aprobadisimo")
        with self.assertRaises(ValueError):
            r.estado_video("cartonero__oro", "va")


class ImportarNuevoTests(ConCarpetas):
    def test_un_png_nuevo_entra_sin_revisar_con_su_corte(self):
        import servidor

        estudio = servidor.Estudio()
        imagen = Image.new("RGB", (256, 256), "white")
        imagen.paste((40, 40, 160), (80, 60, 180, 220))
        cuerpo = io.BytesIO()
        imagen.save(cuerpo, format="PNG")
        with mock.patch.object(estudio, "calcular_rembg"):
            entrada = estudio.importar("cartonero__vaquero_estudio", "vaquero.png", cuerpo.getvalue(), False, None)

        self.assertEqual(entrada["imagen"]["estado"], "sin revisar")
        self.assertEqual((entrada["tipo"], entrada["personaje"], entrada["tipo_skin"]),
                         ("skin", "cartonero", "temática"))
        self.assertEqual(entrada["origen"], "importado")
        corte = estudio.ruta_corte("cartonero__vaquero_estudio", "conectividad")
        alfa = np.array(Image.open(corte))[..., 3]
        self.assertEqual(alfa[0, 0], 0, "el fondo blanco se fue")
        self.assertEqual(alfa[140, 130], 255, "el dibujo quedo")
        with self.assertRaises(servidor.Problema):
            estudio.importar("Con Espacios", "x.png", cuerpo.getvalue(), False, None)


if __name__ == "__main__":
    unittest.main()
