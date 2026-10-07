import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import catalogo  # noqa: E402


class CatalogoTests(unittest.TestCase):
    def test_los_dos_catalogos_del_repo_son_canonicos(self):
        for ruta in catalogo.CATALOGOS:
            self.assertTrue(catalogo.es_canonico(ruta), f"{ruta.name} no sale igual al reescribirlo")

    def test_aplicar_inserta_en_orden_natural_y_queda_canonico(self):
        with tempfile.TemporaryDirectory() as tmp:
            destino = Path(tmp) / "Localizable.xcstrings"
            destino.write_text(catalogo.LOCALIZABLE.read_text(encoding="utf-8"), encoding="utf-8")
            snapshot = Path(tmp) / "claves.json"
            snapshot.write_text(json.dumps({
                "zz.prueba_10": {"es": "diez", "en": "ten"},
                "zz.prueba_9": {"es": "nueve", "en": "nine"},
            }), encoding="utf-8")

            catalogo.aplicar([snapshot], destino)

            self.assertTrue(catalogo.es_canonico(destino))
            claves = list(json.loads(destino.read_text(encoding="utf-8"))["strings"])
            self.assertLess(claves.index("zz.prueba_9"), claves.index("zz.prueba_10"),
                            "Xcode compara los números como números")
            entrada = json.loads(destino.read_text(encoding="utf-8"))["strings"]["zz.prueba_9"]
            self.assertEqual(entrada["extractionState"], "manual")
            self.assertEqual(entrada["localizations"]["en"]["stringUnit"]["state"], "translated")

    def test_una_clave_igual_se_saltea_y_una_distinta_frena_todo(self):
        with tempfile.TemporaryDirectory() as tmp:
            destino = Path(tmp) / "Localizable.xcstrings"
            original = catalogo.LOCALIZABLE.read_text(encoding="utf-8")
            destino.write_text(original, encoding="utf-8")
            existente = json.loads(original)["strings"]["splash.tip.merge"]["localizations"]
            igual = Path(tmp) / "igual.json"
            igual.write_text(json.dumps({"splash.tip.merge": {
                "es": existente["es"]["stringUnit"]["value"],
                "en": existente["en"]["stringUnit"]["value"],
            }}), encoding="utf-8")
            catalogo.aplicar([igual], destino)
            self.assertEqual(destino.read_text(encoding="utf-8"), original)

            distinta = Path(tmp) / "distinta.json"
            distinta.write_text(json.dumps({"splash.tip.merge": {"es": "otra", "en": "other"}}), encoding="utf-8")
            with self.assertRaises(SystemExit):
                catalogo.aplicar([distinta], destino)
            self.assertEqual(destino.read_text(encoding="utf-8"), original, "no escribe nada si frena")


if __name__ == "__main__":
    unittest.main()
