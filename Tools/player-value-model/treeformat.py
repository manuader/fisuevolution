"""Formato C1 (tree-1): validar, predecir, convertir desde XGBoost/LightGBM y exportar.

Semántica (la misma que el evaluador Swift de EconomyKit, TreeEnsemble):
- un nodo es hoja si left[i] == -1 y feature[i] == -1; su resultado es value[i];
- rama: x[feature] < threshold -> left, si no -> right; NaN -> default_left;
- predicción = base_score + suma de las hojas, y con link "expm1" se aplica expm1 al total.
"""
import json
import math

VERSION = "tree-1"
MAX_TREES = 500
MAX_DEPTH = 8
MAX_BYTES = 256 * 1024
LINKS = ("identity", "expm1")


class ModelError(ValueError):
    pass


def _tree_depth(tree):
    depth = 0
    stack = [(0, 0)]
    while stack:
        node, d = stack.pop()
        depth = max(depth, d)
        if tree["left"][node] != -1:
            stack.append((tree["left"][node], d + 1))
            stack.append((tree["right"][node], d + 1))
    return depth


def validate(model):
    """Lanza ModelError si el modelo no cumple C1 (la app lo rechazaría)."""
    if model.get("version") != VERSION:
        raise ModelError("version distinta de tree-1")
    features = model.get("features")
    if not features or len(set(features)) != len(features):
        raise ModelError("features vacío o con repetidos")
    if model.get("link") not in LINKS:
        raise ModelError("link inválido")
    if not math.isfinite(model.get("base_score", math.nan)):
        raise ModelError("base_score no finito")
    trees = model.get("trees")
    if not trees or len(trees) > MAX_TREES:
        raise ModelError("cantidad de árboles fuera de rango")
    keys = ("left", "right", "feature", "threshold", "default_left", "value")
    for t in trees:
        n = len(t["left"])
        if n == 0 or any(len(t[k]) != n for k in keys):
            raise ModelError("arrays de distinto largo")
        for i in range(n):
            leaf = t["left"][i] == -1
            if leaf != (t["right"][i] == -1) or leaf != (t["feature"][i] == -1):
                raise ModelError("nodo medio hoja")
            if not math.isfinite(t["value"][i]) or not math.isfinite(t["threshold"][i]):
                raise ModelError("valor no finito")
            if not leaf:
                if t["feature"][i] < 0:
                    raise ModelError("feature negativo")
                for child in (t["left"][i], t["right"][i]):
                    if not (i < child < n):  # hijos siempre adelante: sin ciclos
                        raise ModelError("hijo fuera de rango o hacia atrás")
                if not (0 <= t["feature"][i] < len(features)):
                    raise ModelError("feature fuera de rango")
        seen = [0] * n
        seen[0] = 1
        for i in range(n):
            if t["left"][i] != -1:
                seen[t["left"][i]] += 1
                seen[t["right"][i]] += 1
        if any(c != 1 for c in seen):
            raise ModelError("nodo huérfano o hijo compartido")
        if _tree_depth(t) > MAX_DEPTH:
            raise ModelError("árbol más profundo que %d" % MAX_DEPTH)
    if len(dumps(model).encode()) > MAX_BYTES:
        raise ModelError("modelo de más de 256 KB")


def predict_row(model, x):
    """x: lista en el orden de model['features']; None o NaN = faltante."""
    total = model["base_score"]
    for t in model["trees"]:
        i = 0
        while t["left"][i] != -1:
            v = x[t["feature"][i]]
            if v is None or v != v:
                go_left = t["default_left"][i]
            else:
                go_left = v < t["threshold"][i]
            i = t["left"][i] if go_left else t["right"][i]
        total += t["value"][i]
    return math.expm1(total) if model["link"] == "expm1" else total


def dumps(model):
    return json.dumps(model, separators=(",", ":"), allow_nan=False)


def _round(v):
    return float("%.9g" % v)


def _flatten(node, tree, convert):
    """Aplana recursivamente un árbol anidado; los hijos quedan siempre con índice mayor que el padre."""
    order = []
    queue = [node]
    index = {}
    while queue:  # BFS: asigna índices
        n = queue.pop(0)
        index[id(n)] = len(order)
        order.append(n)
        for child in convert.children(n):
            queue.append(child)
    for n in order:
        kids = convert.children(n)
        if not kids:
            tree["left"].append(-1); tree["right"].append(-1); tree["feature"].append(-1)
            tree["threshold"].append(0.0); tree["default_left"].append(True)
            tree["value"].append(_round(convert.leaf_value(n)))
        else:
            left, right = kids
            feat, thr, dl = convert.split(n)
            tree["left"].append(index[id(left)]); tree["right"].append(index[id(right)])
            tree["feature"].append(feat); tree["threshold"].append(thr if convert.exact else _round(thr))
            tree["default_left"].append(dl); tree["value"].append(0.0)


class _Xgb:
    exact = False

    def __init__(self, names):
        self.names = names

    def children(self, n):
        if "leaf" in n:
            return []
        by_id = {c["nodeid"]: c for c in n["children"]}
        return [by_id[n["yes"]], by_id[n["no"]]]

    def leaf_value(self, n):
        return n["leaf"]

    def split(self, n):
        return self.names.index(n["split"]), n["split_condition"], n["missing"] == n["yes"]


def from_xgboost_dump(trees_json, feature_names, base_score=0.0, link="expm1"):
    """trees_json: lista de árboles de booster.get_dump(dump_format='json') ya parseados.
    La rama de XGBoost es x < split_condition: igual que C1."""
    conv = _Xgb(feature_names)
    trees = []
    for root in trees_json:
        t = {k: [] for k in ("left", "right", "feature", "threshold", "default_left", "value")}
        _flatten(root, t, conv)
        trees.append(t)
    return {"version": VERSION, "features": list(feature_names), "base_score": _round(base_score),
            "link": link, "trees": trees}


class _Lgb:
    exact = True  # el umbral corrido un ulp no se redondea

    def children(self, n):
        return [] if "leaf_value" in n else [n["left_child"], n["right_child"]]

    def leaf_value(self, n):
        return n["leaf_value"]

    def split(self, n):
        if n.get("decision_type", "<=") != "<=":
            raise ModelError("LightGBM categórico no soportado")
        # LightGBM manda a la izquierda con x <= t; C1 usa x < t: se corre t al siguiente double.
        return n["split_feature"], math.nextafter(float(n["threshold"]), math.inf), bool(n.get("default_left", True))


def from_lightgbm_dump(dump, base_score=0.0, link="expm1"):
    """dump: booster.dump_model() (dict). Respeta feature_names del booster."""
    conv = _Lgb()
    trees = []
    for info in dump["tree_info"]:
        t = {k: [] for k in ("left", "right", "feature", "threshold", "default_left", "value")}
        root = info["tree_structure"]
        if "leaf_value" in root:  # árbol de un solo nodo
            root = {"leaf_value": root["leaf_value"]}
        _flatten(root, t, conv)
        trees.append(t)
    return {"version": VERSION, "features": list(dump["feature_names"]), "base_score": _round(base_score),
            "link": link, "trees": trees}
