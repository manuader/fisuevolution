"""releaseops sin red: el validador, el plan contra un estado inventado, la firma
y la escritura de IDs. Corre con `python3 -m unittest discover Tools/releaseops/tests`."""

import base64
import copy
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from rocore import admob, asc, config as cfg  # noqa: E402

REPO = HERE.parents[2]
CONFIG = cfg.load(REPO / "Distribution" / "release" / "release.json")


def product(short: str) -> dict:
    return next(p for p in CONFIG["inAppPurchases"]["products"] if p["productId"].endswith("." + short))


def asc_state(**overrides) -> dict:
    """Un App Store Connect que coincide con la config, salvo lo que se pise."""
    products = {}
    for index, p in enumerate(CONFIG["inAppPurchases"]["products"]):
        products[p["productId"]] = {
            "id": str(index), "referenceName": p["referenceName"], "type": asc.ASC_TYPE[p["type"]],
            "state": "APPROVED", "reviewNote": p.get("reviewNote"), "familySharable": False,
            "localizations": {loc: {"id": f"{index}-{loc}", **text, "state": "PREPARE_FOR_SUBMISSION"}
                              for loc, text in p["localizations"].items()},
            "priceUSD": p["priceUSD"], "availability": {"id": "a", "territories": 175}}
    for pid, change in overrides.items():
        if change is None:
            del products[pid]
        else:
            products[pid].update(change)
    return {"app": {"id": "app", "name": "HoboEvolution"}, "products": products}


class ValidateTests(unittest.TestCase):
    def test_the_repo_config_is_green(self):
        report = cfg.validate(CONFIG, REPO)
        self.assertTrue(report.ok, report.render())

    def test_a_description_over_45_is_an_error(self):
        broken = copy.deepcopy(CONFIG)
        broken["inAppPurchases"]["products"][0]["localizations"]["es-ES"]["description"] = "x" * 46
        self.assertIn("descripción de 46", cfg.validate(broken, REPO).render())

    def test_a_missing_locale_is_an_error(self):
        broken = copy.deepcopy(CONFIG)
        del broken["inAppPurchases"]["products"][0]["localizations"]["es-ES"]
        self.assertIn("falta la localización es-ES", cfg.validate(broken, REPO).render())

    def test_an_app_id_used_as_unit_is_caught(self):
        broken = copy.deepcopy(CONFIG)
        broken["admob"]["units"][0]["id"] = broken["admob"]["appId"]
        self.assertFalse(cfg.validate(broken, REPO).ok)

    def test_a_product_the_code_asks_for_must_be_configured(self):
        broken = copy.deepcopy(CONFIG)
        broken["inAppPurchases"]["products"] = [p for p in broken["inAppPurchases"]["products"]
                                                if not p["productId"].endswith("remove_ads")]
        self.assertIn("el código pide com.fisuevolution.iap.remove_ads", cfg.validate(broken, REPO).render())


class PlanTests(unittest.TestCase):
    def test_in_sync_means_no_actions(self):
        actions, extra = asc.plan(CONFIG, asc_state())
        self.assertEqual((actions, extra), ([], []))

    def test_a_missing_product_is_created_whole(self):
        pid = product("offer_mudanza")["productId"]
        kinds = [a.kind for a in asc.plan(CONFIG, asc_state(**{pid: None}))[0]]
        self.assertEqual(kinds, ["create-iap", "create-loc", "create-loc", "create-loc", "set-price", "set-availability"])

    def test_a_price_change_on_a_published_product_needs_approval(self):
        pid = product("oro_large")["productId"]
        actions, _ = asc.plan(CONFIG, asc_state(**{pid: {"priceUSD": "4.99"}}))
        self.assertEqual([a.kind for a in actions], ["set-price"])
        self.assertIsNotNone(actions[0].needs_approval)

    def test_an_extra_product_is_reported_never_deleted(self):
        state = asc_state()
        state["products"]["com.fisuevolution.iap.legacy"] = dict(next(iter(state["products"].values())))
        actions, extra = asc.plan(CONFIG, state)
        self.assertEqual(extra, ["com.fisuevolution.iap.legacy"])
        self.assertFalse([a for a in actions if "delete" in a.kind])

    def test_the_draft_wins_over_the_approved_localization(self):
        locs = [
            {"id": "live", "attributes": {"locale": "en-US", "name": "World Cup Skin", "description": "d", "state": "APPROVED"}},
            {"id": "draft", "attributes": {"locale": "en-US", "name": "Mundialista Skin", "description": "d",
                                           "state": "PREPARE_FOR_SUBMISSION"}},
        ]
        for order in (locs, list(reversed(locs))):
            entry = asc._by_locale(order)["en-US"]
            self.assertEqual((entry["id"], entry["live"]), ("draft", "World Cup Skin"))


class TokenTests(unittest.TestCase):
    def test_the_token_is_es256_with_a_raw_64_byte_signature(self):
        with tempfile.TemporaryDirectory() as tmp:
            key = Path(tmp) / "k.p8"
            subprocess.run(["openssl", "ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", str(key)],
                           check=True, capture_output=True)
            token = asc.make_token("issuer", "KEYID", key)
        header, payload, signature = token.split(".")
        pad = lambda s: s + "=" * (-len(s) % 4)  # noqa: E731
        self.assertEqual(json.loads(base64.urlsafe_b64decode(pad(header)))["alg"], "ES256")
        self.assertEqual(json.loads(base64.urlsafe_b64decode(pad(payload)))["aud"], "appstoreconnect-v1")
        self.assertEqual(len(base64.urlsafe_b64decode(pad(signature))), 64)


class AdmobTests(unittest.TestCase):
    def test_sync_code_touches_only_the_changed_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            for relative in CONFIG["codeBindings"]["adUnitIdFiles"]:
                (repo / relative).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(REPO / relative, repo / relative)
            ads = repo / "FisuEvolution/Resources/Config/ads.json"
            before = ads.read_text().splitlines()
            changed = copy.deepcopy(CONFIG)
            unit = next(u for u in changed["admob"]["units"] if u["key"] == "rewardedDaily")
            unit["id"] = "ca-app-pub-8575641544774372/0000000000"
            admob.sync_code(changed, repo, dry_run=False)
            after = ads.read_text().splitlines()
            diff = [(a, b) for a, b in zip(before, after) if a != b]
            self.assertEqual(len(before), len(after))
            self.assertEqual(len(diff), 1)
            self.assertIn("0000000000", diff[0][1])

    def test_plan_lists_only_units_without_id(self):
        pending = copy.deepcopy(CONFIG)
        pending["admob"]["units"][-1]["id"] = None
        self.assertEqual([u["key"] for u in admob.plan(pending)], [pending["admob"]["units"][-1]["key"]])


if __name__ == "__main__":
    unittest.main()
