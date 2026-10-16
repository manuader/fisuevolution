"""Entrenador de referencia en Python puro (cuadrados mínimos, árboles de profundidad acotada).

Existe para que los tests y el humo del pipeline corran sin xgboost/lightgbm. El entrenamiento
real (F6-T4) usa XGBoost o LightGBM vía train.py --engine; este módulo produce el mismo C1.
"""
import math

from treeformat import VERSION, _round


def _best_split(X, g, rows, min_leaf):
    best = None
    n = len(rows)
    total = sum(g[r] for r in rows)
    for f in range(len(X[0])):
        vals = sorted((X[r][f], g[r]) for r in rows if X[r][f] == X[r][f])
        left_sum = 0.0
        for k in range(1, len(vals)):
            left_sum += vals[k - 1][1]
            if vals[k][0] == vals[k - 1][0] or k < min_leaf or len(vals) - k < min_leaf:
                continue
            # los faltantes van a la izquierda: se suman a la izquierda en la ganancia
            miss = n - len(vals)
            miss_sum = total - sum(v[1] for v in vals)
            ls, ln = left_sum + miss_sum, k + miss
            rs, rn = total - ls, n - ln
            gain = ls * ls / ln + rs * rs / rn - total * total / n
            if best is None or gain > best[0]:
                best = (gain, f, (vals[k][0] + vals[k - 1][0]) / 2)
    return best


def _grow(X, g, rows, depth, max_depth, min_leaf, lr, tree):
    idx = len(tree["left"])
    for k, v in (("left", -1), ("right", -1), ("feature", -1), ("threshold", 0.0),
                 ("default_left", True), ("value", 0.0)):
        tree[k].append(v)
    split = _best_split(X, g, rows, min_leaf) if depth < max_depth and len(rows) >= 2 * min_leaf else None
    if split is None or split[0] <= 1e-12:
        tree["value"][idx] = _round(lr * sum(g[r] for r in rows) / len(rows))
        return idx
    _, f, thr = split
    thr = _round(thr)
    left = [r for r in rows if not (X[r][f] == X[r][f]) or X[r][f] < thr]
    right = [r for r in rows if X[r][f] == X[r][f] and X[r][f] >= thr]
    tree["feature"][idx], tree["threshold"][idx] = f, thr
    tree["left"][idx] = _grow(X, g, left, depth + 1, max_depth, min_leaf, lr, tree)
    tree["right"][idx] = _grow(X, g, right, depth + 1, max_depth, min_leaf, lr, tree)
    return idx


def _tree_predict(t, x):
    i = 0
    while t["left"][i] != -1:
        v = x[t["feature"][i]]
        go_left = t["default_left"][i] if v != v else v < t["threshold"][i]
        i = t["left"][i] if go_left else t["right"][i]
    return t["value"][i]


def train(X, y, features, n_trees=50, max_depth=3, learning_rate=0.2, min_leaf=5, link="expm1"):
    """X: filas (listas, NaN = faltante); y en la escala ya transformada (log1p). Devuelve un modelo C1."""
    base = sum(y) / len(y)
    pred = [base] * len(y)
    trees = []
    for _ in range(n_trees):
        g = [y[i] - pred[i] for i in range(len(y))]
        t = {k: [] for k in ("left", "right", "feature", "threshold", "default_left", "value")}
        _grow(X, g, list(range(len(X))), 0, max_depth, min_leaf, learning_rate, t)
        trees.append(t)
        for i in range(len(X)):
            pred[i] += _tree_predict(t, X[i])
    return {"version": VERSION, "features": list(features), "base_score": _round(base),
            "link": link, "trees": trees}
