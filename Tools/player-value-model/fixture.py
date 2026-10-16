#!/usr/bin/env python3
"""Regenera / verifica el fixture del evaluador Swift (F6-T1) contra el predict de Python.

  python3 fixture.py check <tree_fixture.json> <tree_fixture_cases.json>
      Verifica que predict_row dé el `expected` de cada caso (tolerancia relativa 1e-12, como el Swift): las mismas
      predicciones que calcula a mano el test Swift (TreeEnsembleTests).
  python3 fixture.py write <tree_fixture.json> <tree_fixture_cases.json>
      Escribe el fixture canónico (3 árboles chicos, un ejemplo de cada rama, NaN y expm1) y
      sus casos con las predicciones calculadas por este predict.
Los casos son [{"features": [...], "expected": x}]; null en un feature = faltante (NaN).
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import treeformat  # noqa: E402

FIXTURE = {
    "version": "tree-1", "features": ["a", "b"], "base_score": 0.1, "link": "expm1",
    "trees": [
        {"left": [1, -1, -1], "right": [2, -1, -1], "feature": [0, -1, -1], "threshold": [1.5, 0, 0],
         "default_left": [True, True, True], "value": [0, 0.12, -0.03]},
        {"left": [1, -1, -1], "right": [2, -1, -1], "feature": [1, -1, -1], "threshold": [10.0, 0, 0],
         "default_left": [False, True, True], "value": [0, 0.5, 0.25]},
        {"left": [1, -1, 3, -1, -1], "right": [2, -1, 4, -1, -1], "feature": [0, -1, 1, -1, -1],
         "threshold": [3.0, 0, 20.0, 0, 0], "default_left": [True, True, True, True, True],
         "value": [0, 0.01, 0, -0.2, 0.3]},
    ],
}
CASES_X = [[1.0, 5.0], [2.0, 15.0], [1.5, 10.0], [None, 5.0], [2.0, None], [4.0, 30.0], [4.0, 10.0], [None, None]]


def _x(row, n=None):
    """null = NaN; un vector más corto que features se completa con NaN (igual que el evaluador Swift)."""
    x = [math.nan if v is None else v for v in row]
    return x + [math.nan] * ((n or 0) - len(x))


def check(fixture_path, cases_path):
    with open(fixture_path) as f:
        model = json.load(f)
    treeformat.validate(model)
    with open(cases_path) as f:
        cases = json.load(f)
    n = len(model["features"])
    bad = [c for c in cases if not math.isclose(treeformat.predict_row(model, _x(c["features"], n)), c["expected"],
                                                rel_tol=1e-12, abs_tol=1e-12)]
    print("%d casos, %d discrepancias" % (len(cases), len(bad)))
    for c in bad:
        print("  %s: esperado %r, Python %r" % (c["features"], c["expected"], treeformat.predict_row(model, _x(c["features"], n))))
    return 1 if bad else 0


def write(fixture_path, cases_path):
    treeformat.validate(FIXTURE)
    cases = [{"features": r, "expected": treeformat.predict_row(FIXTURE, _x(r))} for r in CASES_X]
    with open(fixture_path, "w") as f:
        json.dump(FIXTURE, f, indent=2)
    with open(cases_path, "w") as f:
        json.dump(cases, f, indent=2)
    print("escritos %s y %s (%d casos)" % (fixture_path, cases_path, len(cases)))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] not in ("check", "write"):
        sys.exit(__doc__)
    sys.exit((check if sys.argv[1] == "check" else write)(sys.argv[2], sys.argv[3]))
