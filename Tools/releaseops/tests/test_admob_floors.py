"""El plan de pisos por país, sin red y sin escribir nada.
Corre con `python3 -m unittest discover Tools/releaseops/tests`."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from rocore import admob_floors as floors  # noqa: E402

FIXTURES = HERE / "fixtures" / "admob_floors"
TIERS_JSON = FIXTURES / "player_value.json"
REPORT_CSV = FIXTURES / "report.csv"
FORMATS = ["interstitial", "rewarded"]


def group(plan: dict, name: str) -> dict:
    return next(g for g in plan["groups"] if g["group"] == name)


class FloorsPlanTests(unittest.TestCase):
    def setUp(self):
        self.tiers, self.default = floors.load_tiers(TIERS_JSON)
        self.report = floors.read_report(REPORT_CSV)

    def plan(self, **kwargs):
        return floors.build(self.tiers, self.default, FORMATS, self.report, **kwargs)

    def test_los_paises_quedan_agrupados_por_tier(self):
        plan = self.plan()
        self.assertEqual(group(plan, "tier1-rewarded")["countries"], ["DEU", "GBR", "USA"])
        self.assertEqual(group(plan, "tier2-rewarded")["countries"], ["ESP", "FRA"])
        self.assertEqual(len(plan["groups"]), 3 * len(FORMATS))

    def test_el_piso_es_el_factor_por_el_p25_del_tier(self):
        # tier 1, rewarded, iOS: eCPM 20, 14 y 10 → p25 = 12; la fila de Android no cuenta.
        g = group(self.plan(), "tier1-rewarded")
        self.assertEqual(g["ecpmP25"], 12.0)
        self.assertEqual(g["floorEcpm"], 6.0)
        self.assertEqual(group(self.plan(factor=0.25), "tier1-rewarded")["floorEcpm"], 3.0)

    def test_sin_csv_los_pisos_quedan_a_medir(self):
        plan = floors.build(self.tiers, self.default, FORMATS, None)
        self.assertFalse(plan["withReport"])
        self.assertTrue(all(g["floorEcpm"] == floors.TO_MEASURE for g in plan["groups"]))
        self.assertTrue(all(g["ecpmP25"] is None for g in plan["groups"]))

    def test_un_pais_sin_datos_cae_a_su_tier(self):
        # Colombia no está en la tabla: entra a la tier por defecto (3) y suma a su p25.
        g = group(self.plan(), "tier3-rewarded")
        self.assertIn("COL", g["countries"])
        self.assertEqual(g["countriesWithData"], 3)
        # Argentina y México tienen datos; Brasil no tiene filas y comparte el piso de su tier.
        self.assertIn("BRA", g["countries"])
        self.assertIsInstance(g["floorEcpm"], float)

    def test_tier_o_formato_sin_impresiones_suficientes_queda_a_medir(self):
        # ESP × interstitial tiene 100 impresiones (< 1000): el eCPM sería ruido.
        self.assertEqual(group(self.plan(), "tier2-interstitial")["floorEcpm"], floors.TO_MEASURE)

    def test_ningun_piso_supera_el_p25_medido(self):
        plan = self.plan()
        for g in plan["groups"]:
            if isinstance(g["floorEcpm"], float):
                self.assertLessEqual(g["floorEcpm"], g["ecpmP25"], g["group"])
        for bad in (0, -0.1, 1.5):
            with self.assertRaises(floors.FloorsError):
                self.plan(factor=bad)

    def test_los_codigos_alfa2_del_informe_se_leen_como_alfa3(self):
        self.assertIn(("USA", "rewarded"), self.report)
        self.assertNotIn(("US", "rewarded"), self.report)

    def test_un_csv_sin_columnas_obligatorias_se_rechaza(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.csv"
            bad.write_text("COUNTRY,FORMAT\nUS,rewarded\n", encoding="utf-8")
            with self.assertRaises(floors.FloorsError):
                floors.read_report(bad)


class FloorsCliTests(unittest.TestCase):
    def run_cli(self, *extra):
        script = HERE.parent / "releaseops.py"
        return subprocess.run([sys.executable, str(script), "admob", "floors-plan", "--tiers", str(TIERS_JSON), *extra],
                              capture_output=True, text=True)

    def test_con_csv_imprime_la_tabla_y_el_json_sin_escribir_nada(self):
        before = (HERE.parents[2] / "Distribution" / "release" / "release.json").read_bytes()
        result = self.run_cli("--report", str(REPORT_CSV))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("tier1-rewarded", result.stdout)
        plan = json.loads(result.stdout[result.stdout.index("{"):])
        self.assertEqual(group(plan, "tier1-rewarded")["floorEcpm"], 6.0)
        after = (HERE.parents[2] / "Distribution" / "release" / "release.json").read_bytes()
        self.assertEqual(before, after)

    def test_sin_csv_avisa_que_queda_a_medir(self):
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("a medir", result.stdout)


if __name__ == "__main__":
    unittest.main()
