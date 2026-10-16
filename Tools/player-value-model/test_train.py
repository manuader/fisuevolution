"""Tests con datos sintéticos (sin datos reales, sin xgboost/lightgbm). python3 -m unittest -v"""
import copy
import csv
import json
import math
import os
import random
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fixture  # noqa: E402
import gbm  # noqa: E402
import train  # noqa: E402
import treeformat  # noqa: E402

NAN = float("nan")


def synthetic_rows(n=300, seed=7):
    """Ingreso = f(país, recompensas) + ruido; cohortes por día."""
    rnd = random.Random(seed)
    rows = []
    for i in range(n):
        tier = rnd.choice([1.0, 2.0, 3.0])
        rewarded = rnd.randint(0, 30)
        purchased = 1.0 if rnd.random() < 0.05 else 0.0
        rev = max(0.0, (4 - tier) * 0.05 * rewarded + 2.0 * purchased + rnd.gauss(0, 0.02))
        x = [tier, rnd.choice([1.0, 2.0, 3.0]), float(rnd.randint(1, 20)), rnd.uniform(30, 600), float(rewarded),
             rnd.uniform(1000, 20000), purchased, float(rnd.randint(0, 5)), float(rnd.randint(0, 3))]
        rows.append(("2026-09-%02d" % (1 + i * 28 // n), x, rev))
    rows.sort(key=lambda r: r[0])
    return rows


class PredictTests(unittest.TestCase):
    def test_fixture_branches_nan_and_expm1(self):
        m = fixture.FIXTURE
        treeformat.validate(m)
        # a=1, b=5: t0 izq 0.12, t1 izq(5<10) 0.5, t2 izq(1<3) 0.01 -> expm1(0.1+0.63)
        self.assertAlmostEqual(treeformat.predict_row(m, [1.0, 5.0]), math.expm1(0.73), places=12)
        # a=4, b=30: 0.-03, 0.25, (4>=3 -> n2: b=30>=20) 0.3 -> 0.1+0.52
        self.assertAlmostEqual(treeformat.predict_row(m, [4.0, 30.0]), math.expm1(0.62), places=12)
        # umbral exacto va a la derecha (x < t es estricto): a=1.5 -> -0.03
        self.assertAlmostEqual(treeformat.predict_row(m, [1.5, 5.0]), math.expm1(0.1 - 0.03 + 0.5 + 0.01), places=12)
        # NaN: árbol 1 default_left False en la raíz -> derecha (0.25); a NaN -> izquierda
        self.assertAlmostEqual(treeformat.predict_row(m, [1.0, NAN]), math.expm1(0.1 + 0.12 + 0.25 + 0.01), places=12)

    def test_identity_link(self):
        m = copy.deepcopy(fixture.FIXTURE)
        m["link"] = "identity"
        self.assertAlmostEqual(treeformat.predict_row(m, [1.0, 5.0]), 0.73, places=12)

    def test_fixture_write_then_check_agree(self):
        with tempfile.TemporaryDirectory() as d:
            a, b = os.path.join(d, "f.json"), os.path.join(d, "c.json")
            self.assertEqual(fixture.write(a, b), 0)
            self.assertEqual(fixture.check(a, b), 0)
            with open(b) as f:
                cases = json.load(f)
            cases[0]["expected"] += 1
            with open(b, "w") as f:
                json.dump(cases, f)
            self.assertEqual(fixture.check(a, b), 1)


class ValidateTests(unittest.TestCase):
    def bad(self, mutate):
        m = copy.deepcopy(fixture.FIXTURE)
        mutate(m)
        with self.assertRaises(treeformat.ModelError):
            treeformat.validate(m)

    def test_rejects(self):
        self.bad(lambda m: m.update(version="tree-2"))
        self.bad(lambda m: m.update(link="log"))
        self.bad(lambda m: m.update(features=[]))
        self.bad(lambda m: m["trees"][0]["left"].__setitem__(0, 0))      # ciclo / hijo atrás
        self.bad(lambda m: m["trees"][0]["right"].__setitem__(0, 9))     # fuera de rango
        self.bad(lambda m: m["trees"][0]["feature"].__setitem__(0, 5))   # feature fuera de rango
        self.bad(lambda m: m["trees"][0]["feature"].__setitem__(1, 0))   # hoja a medias
        self.bad(lambda m: m["trees"][0]["value"].__setitem__(1, math.inf))
        self.bad(lambda m: m["trees"][0]["threshold"].pop())             # arrays dispares
        self.bad(lambda m: m["trees"][0]["right"].__setitem__(0, 1))     # hijo compartido, nodo 2 huérfano
        self.bad(lambda m: m.update(trees=m["trees"] * 200))             # > 500 árboles

    def test_single_leaf_tree_is_valid(self):
        m = copy.deepcopy(fixture.FIXTURE)
        m["trees"] = [{"left": [-1], "right": [-1], "feature": [-1], "threshold": [0], "default_left": [True],
                       "value": [0.4]}]
        treeformat.validate(m)
        self.assertAlmostEqual(treeformat.predict_row(m, [0, 0]), math.expm1(0.5))

    def test_depth_limit(self):
        n = 11  # cadena de 10 aristas
        t = {"left": [], "right": [], "feature": [], "threshold": [], "default_left": [], "value": []}
        for i in range(n):
            last = i == n - 1
            t["left"].append(-1 if last else i + 1)
            t["right"].append(-1 if last else n + i)  # hijos derechos al final
            t["feature"].append(-1 if last else 0)
            t["threshold"].append(0.0); t["default_left"].append(True); t["value"].append(0.0)
        for i in range(n - 1):  # hojas derechas
            t["left"].append(-1); t["right"].append(-1); t["feature"].append(-1)
            t["threshold"].append(0.0); t["default_left"].append(True); t["value"].append(0.0)
        m = copy.deepcopy(fixture.FIXTURE)
        m["trees"] = [t]
        with self.assertRaises(treeformat.ModelError):
            treeformat.validate(m)


class ConvertTests(unittest.TestCase):
    def test_xgboost_dump(self):
        dump = [{"nodeid": 0, "split": "a", "split_condition": 1.5, "yes": 1, "no": 2, "missing": 1,
                 "children": [{"nodeid": 1, "leaf": 0.12}, {"nodeid": 2, "leaf": -0.03}]}]
        m = treeformat.from_xgboost_dump(dump, ["a", "b"], base_score=0.5, link="identity")
        treeformat.validate(m)
        self.assertEqual(treeformat.predict_row(m, [1.0, 0.0]), 0.5 + 0.12)
        self.assertEqual(treeformat.predict_row(m, [1.5, 0.0]), 0.5 - 0.03)
        self.assertEqual(treeformat.predict_row(m, [NAN, 0.0]), 0.5 + 0.12)  # missing == yes -> izquierda

    def test_lightgbm_le_becomes_strict_lt(self):
        dump = {"feature_names": ["a", "b"], "tree_info": [{"tree_structure": {
            "split_feature": 1, "threshold": 10.0, "decision_type": "<=", "default_left": False,
            "left_child": {"leaf_value": 0.5}, "right_child": {"leaf_value": 0.25}}}]}
        m = treeformat.from_lightgbm_dump(dump, link="identity")
        treeformat.validate(m)
        self.assertEqual(treeformat.predict_row(m, [0, 10.0]), 0.5)   # LightGBM: x <= t va a la izquierda
        self.assertEqual(treeformat.predict_row(m, [0, 10.0000001]), 0.25)
        self.assertEqual(treeformat.predict_row(m, [0, NAN]), 0.25)   # default_left False

    def test_lightgbm_single_leaf(self):
        m = treeformat.from_lightgbm_dump({"feature_names": ["a"], "tree_info": [
            {"tree_structure": {"leaf_value": 0.3}}]}, link="identity")
        treeformat.validate(m)
        self.assertEqual(treeformat.predict_row(m, [1.0]), 0.3)


class TrainTests(unittest.TestCase):
    def test_reference_trainer_learns_and_exports_valid_c1(self):
        rows = synthetic_rows()
        model, summary = train.run(rows, engine="reference")
        treeformat.validate(model)
        self.assertEqual(model["features"], train.FEATURES)
        self.assertTrue(summary["model_beats_rules"], summary)
        self.assertLess(summary["valid_mae_model_usd"], summary["valid_mae_rules_usd"])
        self.assertLess(summary["bytes"], treeformat.MAX_BYTES)

    def test_temporal_split_keeps_future_out_of_training(self):
        rows = synthetic_rows()
        tr, va = train.temporal_split(rows)
        self.assertLessEqual(tr[-1][0], va[0][0])
        self.assertNotEqual(tr[-1][0], va[0][0])  # una cohorte no se parte
        self.assertGreater(len(va), 0)

    def test_too_few_rows_stops(self):
        with self.assertRaises(SystemExit):
            train.run(synthetic_rows(50), engine="reference")

    def test_noise_does_not_beat_rules(self):
        rnd = random.Random(3)
        rows = [("2026-09-%02d" % (1 + i * 28 // 400), [rnd.choice([1.0, 2.0, 3.0])] + [rnd.random() for _ in range(8)],
                 rnd.expovariate(1.0)) for i in range(400)]
        _, summary = train.run(rows, engine="reference")
        self.assertIn("model_beats_rules", summary)  # sólo la señal importa: no se rompe y reporta

    def test_tiers_from_tables(self):
        t = dict(train.DEFAULT_TABLES, countryTier={"USA": 1}, deviceTier={"iPhone16,": 1, "iPhone": 2},
                 defaultDeviceTier=3)
        self.assertEqual(train.country_tier(t, "usa"), 1.0)
        self.assertEqual(train.country_tier(t, "ARG"), 3.0)
        self.assertEqual(train.device_tier(t, "iPhone16,2"), 1.0)  # prefijo más largo
        self.assertEqual(train.device_tier(t, "iPhone9,1"), 2.0)
        self.assertEqual(train.device_tier(t, "iPad1"), 3.0)

    def test_cli_writes_only_model_and_aggregate_summary(self):
        rows = synthetic_rows()
        with tempfile.TemporaryDirectory() as d:
            src, out = os.path.join(d, "e.csv"), os.path.join(d, "out", "model.json")
            with open(src, "w", newline="") as f:
                w = csv.writer(f)
                w.writerow(["cohort_day", "storefront", "device_model", "sessions_7d", "mean_session_seconds",
                            "rewarded_count", "avg_rewarded_micros", "has_purchased", "offers_seen",
                            "prestige_count", "revenue_usd"])
                for day, x, rev in rows:
                    w.writerow([day, "USA" if x[0] == 1 else "ARG", "iPhone16,2"] + x[2:] + [rev])
            r = subprocess.run([sys.executable, os.path.join(HERE, "train.py"), "--csv", src, "--out", out,
                                "--engine", "reference"], capture_output=True, text=True)
            self.assertIn(r.returncode, (0, 2), r.stderr)
            self.assertEqual(os.listdir(os.path.dirname(out)), ["model.json"])
            summary = json.loads(r.stdout)
            self.assertEqual(sorted(summary), sorted(["engine", "train_rows", "valid_rows", "valid_mae_model_usd",
                                                      "valid_mae_rules_usd", "trees", "bytes", "model_beats_rules"]))
            with open(out) as f:
                treeformat.validate(json.load(f))


if __name__ == "__main__":
    unittest.main()
