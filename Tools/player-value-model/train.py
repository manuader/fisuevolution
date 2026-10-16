#!/usr/bin/env python3
"""Entrena el valor por jugador (F6) y exporta el modelo C1 (tree-1).

Lee el CSV de export.sql (un renglón por instalación, SIN id) y escribe SOLO dos cosas:
el modelo (árboles, sin datos de nadie) y un resumen agregado (errores, cantidades).
Nunca imprime ni guarda un renglón por instalación.

Uso:
  python3 train.py --csv export.csv --out out/model.json [--tables player_value.json]
                   [--engine auto|xgboost|lightgbm|reference]
"""
import argparse
import csv
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gbm  # noqa: E402
import treeformat  # noqa: E402

# El orden y los nombres son el contrato con PlayerValueFeatures (F6-T2).
FEATURES = ["country_tier", "device_tier", "sessions_7d", "mean_session_seconds", "rewarded_count",
            "avg_rewarded_micros", "has_purchased", "offers_seen", "prestige_count"]
NUMERIC = FEATURES[2:]
DEFAULT_TABLES = {"countryTier": {}, "defaultCountryTier": 3, "deviceTier": {}, "defaultDeviceTier": 3}
MIN_ROWS = 200


def country_tier(tables, storefront):
    return float(tables["countryTier"].get((storefront or "").upper(), tables["defaultCountryTier"]))


def device_tier(tables, model):
    best = None
    for prefix, tier in tables["deviceTier"].items():
        if (model or "").startswith(prefix) and (best is None or len(prefix) > len(best[0])):
            best = (prefix, tier)
    return float(best[1] if best else tables["defaultDeviceTier"])


def _num(s):
    try:
        v = float(s)
        return v if math.isfinite(v) else float("nan")
    except (TypeError, ValueError):
        return float("nan")


def load_rows(path, tables):
    """Devuelve [(cohort_day, X, revenue_usd)] ordenado por cohorte."""
    rows = []
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            x = [country_tier(tables, r.get("storefront")), device_tier(tables, r.get("device_model"))]
            x += [_num(r.get(k)) for k in NUMERIC]
            rev = _num(r.get("revenue_usd"))
            rows.append((r["cohort_day"], x, 0.0 if rev != rev else max(0.0, rev)))
    rows.sort(key=lambda t: t[0])
    return rows


def temporal_split(rows, valid_fraction=0.2):
    """Valida con las cohortes MÁS NUEVAS: nunca se mezcla futuro en el entrenamiento."""
    cut = int(len(rows) * (1 - valid_fraction))
    while 0 < cut < len(rows) and rows[cut][0] == rows[cut - 1][0]:
        cut += 1  # una cohorte no se parte
    return rows[:cut], rows[cut:]


def mae(pred, actual):
    return sum(abs(p - a) for p, a in zip(pred, actual)) / len(actual)


def baseline_predictor(train_rows):
    """Las reglas de F1 en esencia: el ingreso depende del tier de país (promedio del tier)."""
    sums = {}
    for _, x, y in train_rows:
        s = sums.setdefault(x[0], [0.0, 0])
        s[0] += y
        s[1] += 1
    overall = sum(y for _, _, y in train_rows) / len(train_rows)
    means = {t: s / n for t, (s, n) in sums.items()}
    return lambda x: means.get(x[0], overall)


def _train_engine(engine, Xt, yt, Xv, yv):
    if engine in ("auto", "xgboost"):
        try:
            import xgboost as xgb
            d = xgb.DMatrix(Xt, label=yt, feature_names=FEATURES)
            dv = xgb.DMatrix(Xv, label=yv, feature_names=FEATURES)
            booster = xgb.train({"max_depth": 4, "eta": 0.05, "objective": "reg:squarederror",
                                 "min_child_weight": 20, "subsample": 0.8, "base_score": sum(yt) / len(yt)},
                                d, num_boost_round=400, evals=[(dv, "valid")],
                                early_stopping_rounds=20, verbose_eval=False)
            trees = [json.loads(t) for t in booster.get_dump(dump_format="json")]
            n = booster.best_iteration + 1
            return treeformat.from_xgboost_dump(trees[:n], FEATURES, base_score=sum(yt) / len(yt)), "xgboost"
        except ImportError:
            if engine == "xgboost":
                raise
    if engine in ("auto", "lightgbm"):
        try:
            import lightgbm as lgb
            booster = lgb.train({"objective": "regression", "num_leaves": 15, "max_depth": 4,
                                 "learning_rate": 0.05, "min_data_in_leaf": 20, "verbose": -1},
                                lgb.Dataset(Xt, label=yt, feature_name=FEATURES), num_boost_round=400,
                                valid_sets=[lgb.Dataset(Xv, label=yv)],
                                callbacks=[lgb.early_stopping(20, verbose=False)])
            # LightGBM mete el promedio de la etiqueta en las hojas del primer árbol: base_score = 0.
            return treeformat.from_lightgbm_dump(booster.dump_model(num_iteration=booster.best_iteration)), "lightgbm"
        except ImportError:
            if engine == "lightgbm":
                raise
    return gbm.train(Xt, yt, FEATURES, n_trees=40, max_depth=3), "reference"


def run(rows, engine="auto", min_rows=MIN_ROWS):
    """Devuelve (modelo, resumen). El resumen es agregado: nada por instalación."""
    if len(rows) < min_rows:
        raise SystemExit("Faltan datos: %d instalaciones etiquetadas, mínimo %d." % (len(rows), min_rows))
    train_rows, valid_rows = temporal_split(rows)
    if not valid_rows:
        raise SystemExit("Sin cohortes nuevas para validar.")
    Xt, yt = [r[1] for r in train_rows], [math.log1p(r[2]) for r in train_rows]
    Xv, yv_raw = [r[1] for r in valid_rows], [r[2] for r in valid_rows]
    model, used = _train_engine(engine, Xt, yt, Xv, [math.log1p(v) for v in yv_raw])
    treeformat.validate(model)
    model_pred = [max(0.0, treeformat.predict_row(model, x)) for x in Xv]
    base = baseline_predictor(train_rows)
    base_pred = [base(x) for x in Xv]
    summary = {"engine": used, "train_rows": len(train_rows), "valid_rows": len(valid_rows),
               "valid_mae_model_usd": round(mae(model_pred, yv_raw), 6),
               "valid_mae_rules_usd": round(mae(base_pred, yv_raw), 6),
               "trees": len(model["trees"]), "bytes": len(treeformat.dumps(model))}
    summary["model_beats_rules"] = summary["valid_mae_model_usd"] < summary["valid_mae_rules_usd"]
    return model, summary


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--csv", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--tables", help="player_value.json (las tiers de país y de dispositivo de la app)")
    p.add_argument("--engine", default="auto", choices=["auto", "xgboost", "lightgbm", "reference"])
    a = p.parse_args(argv)
    tables = dict(DEFAULT_TABLES)
    if a.tables:
        with open(a.tables) as f:
            tables.update(json.load(f))
    model, summary = run(load_rows(a.csv, tables), a.engine)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    with open(a.out, "w") as f:
        f.write(treeformat.dumps(model))
    print(json.dumps(summary, indent=2))
    if not summary["model_beats_rules"]:
        print("El modelo NO gana a las reglas en la validación temporal: F6 queda en reglas (R8).", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
