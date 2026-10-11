"""app verify: los chequeos del .app contra plists de fixture, sin compilar nada.
Corre con `python3 -m unittest discover Tools/releaseops/tests`."""

import copy
import plistlib
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from rocore import appcheck, config as cfg  # noqa: E402

FIX = HERE / "fixtures" / "appcheck"
REPO = HERE.parents[2]
CONFIG = cfg.load(REPO / "Distribution" / "release" / "release.json")


class AppCheckTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.app = self.tmp / "FisuEvolution.app"
        self.app.mkdir()
        self.info = plistlib.loads((FIX / "Info.plist").read_bytes())
        self.privacy = plistlib.loads((FIX / "PrivacyInfo.xcprivacy").read_bytes())
        self.source_info = FIX / "Info.source.plist"
        self.source_privacy = FIX / "PrivacyInfo.xcprivacy"
        self.config = copy.deepcopy(CONFIG)

    def run_verify(self, with_privacy=True):
        (self.app / "Info.plist").write_bytes(plistlib.dumps(self.info))
        if with_privacy:
            (self.app / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps(self.privacy))
        return appcheck.verify(self.app, self.source_info, self.source_privacy, self.config)

    def failed(self, checks):
        return {c.name: c for c in checks if not c.ok}

    def test_green(self):
        self.assertEqual(self.failed(self.run_verify()), {})

    def test_device_family(self):
        self.info["UIDeviceFamily"] = [1]
        self.assertIn("UIDeviceFamily", self.failed(self.run_verify()))

    def test_full_screen(self):
        del self.info["UIRequiresFullScreen"]
        self.assertIn("UIRequiresFullScreen", self.failed(self.run_verify()))

    def test_tracking_differs_from_source(self):
        self.privacy["NSPrivacyTracking"] = True
        self.privacy["NSPrivacyTrackingDomains"] = ["x.example"]
        self.assertIn("NSPrivacyTracking", self.failed(self.run_verify()))

    def test_tracking_true_without_domains(self):
        source = self.tmp / "source.xcprivacy"
        source.write_bytes(plistlib.dumps({"NSPrivacyTracking": True}))
        self.source_privacy = source
        self.privacy = {"NSPrivacyTracking": True, "NSPrivacyTrackingDomains": []}
        failed = self.failed(self.run_verify())
        self.assertIn("NSPrivacyTracking", failed)
        self.assertIn("ITMS-91064", failed["NSPrivacyTracking"].detail)

    def test_admob_app_id(self):
        self.info["GADApplicationIdentifier"] = "ca-app-pub-1~2"
        self.assertIn("GADApplicationIdentifier", self.failed(self.run_verify()))

    def test_missing_unity_id_names_the_network(self):
        self.info["SKAdNetworkItems"] = [i for i in self.info["SKAdNetworkItems"]
                                         if i["SKAdNetworkIdentifier"] != "4dzt52r2t5.skadnetwork"]
        failed = self.failed(self.run_verify())
        self.assertIn("SKAdNetworkItems", failed)
        self.assertIn("unity", failed["SKAdNetworkItems"].detail)

    def test_rejected_network_is_not_required(self):
        self.assertIn("status", self.config["mediation"]["networks"]["applovin"])
        self.assertNotIn("applovin", appcheck.required_networks(self.config))

    def test_missing_id_from_source(self):
        self.info["SKAdNetworkItems"] = [i for i in self.info["SKAdNetworkItems"]
                                         if i["SKAdNetworkIdentifier"] != "ludvb6z3bs.skadnetwork"]
        failed = self.failed(self.run_verify())
        self.assertIn("ludvb6z3bs", failed["SKAdNetworkItems"].detail)

    def test_build_four(self):
        self.info["CFBundleVersion"] = "4"
        self.assertIn("CFBundleVersion", self.failed(self.run_verify()))

    def test_version_mismatch(self):
        self.info["CFBundleShortVersionString"] = "1.9.0"
        self.assertIn("CFBundleShortVersionString", self.failed(self.run_verify()))

    def test_missing_privacy_manifest(self):
        self.assertIn("PrivacyInfo.xcprivacy", self.failed(self.run_verify(with_privacy=False)))

    def test_locate_app_in_xcarchive(self):
        archive = self.tmp / "Fisu.xcarchive"
        inner = archive / "Products" / "Applications" / "Fisu.app"
        inner.mkdir(parents=True)
        self.assertEqual(appcheck.locate_app(archive), inner)
        self.assertEqual(appcheck.locate_app(self.app), self.app)

    def test_xcarchive_without_app(self):
        archive = self.tmp / "Empty.xcarchive"
        (archive / "Products" / "Applications").mkdir(parents=True)
        with self.assertRaises(FileNotFoundError):
            appcheck.locate_app(archive)


if __name__ == "__main__":
    unittest.main()
