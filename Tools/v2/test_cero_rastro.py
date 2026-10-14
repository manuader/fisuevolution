import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cero_rastro  # noqa: E402


def rastro(linea, ruta="FisuEvolution/UI/Algo.swift"):
    return bool(cero_rastro.PALABRA.search(cero_rastro.sin_excepciones(linea, ruta)))


class CeroRastroTests(unittest.TestCase):
    def test_encuentra_la_moneda_vieja_en_todas_sus_formas(self):
        for linea in ("player.meta.oro += 1", "struct OroShopRow {", "buyOroShopItem(id: x)",
                      "// el ORO comprado", '"ui_oro"', "icon_ui_oro_autotap.mov",
                      '"kind": "oro"', "purchasedOroReconstructed", "oro_shop.json"):
            self.assertTrue(rastro(linea), linea)

    def test_no_confunde_palabras_que_solo_la_contienen(self):
        for linea in ("el tesoro del colchón", "corona_solar", "floorOrdinal", "humorous",
                      "el foro", "semaforo", "repoRoot", "Moron", "decoro"):
            self.assertFalse(rastro(linea), linea)

    def test_los_ids_de_asc_y_el_arte_de_la_skin_dorada_son_excepcion_en_todos_lados(self):
        self.assertFalse(rastro('"com.fisuevolution.iap.oro_medium"'))
        self.assertFalse(rastro('product("oro_large")'))
        self.assertFalse(rastro('"textureKey": "ceo_idle__oro"'))

    def test_las_claves_del_save_viejo_solo_en_su_archivo(self):
        linea = 'case blue = "oro"'
        self.assertFalse(rastro(linea, "Packages/EconomyKit/Sources/EconomyKit/PlayerState.swift"))
        self.assertTrue(rastro(linea, "FisuEvolution/UI/Store/StoreView.swift"))

    def test_el_id_de_la_skin_dorada_solo_en_los_archivos_de_skins(self):
        linea = '"id": "oro",'
        self.assertFalse(rastro(linea, "FisuEvolution/Resources/Config/skins.json"))
        self.assertTrue(rastro(linea, "FisuEvolution/Resources/Config/wheel.json"))

    def test_el_repo_no_tiene_rastros(self):
        hallados = cero_rastro.rastros()
        self.assertEqual(hallados, [], "\n" + "\n".join(hallados[:20]))


if __name__ == "__main__":
    unittest.main()
