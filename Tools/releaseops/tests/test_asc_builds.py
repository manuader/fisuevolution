"""asc builds: el próximo número libre contra respuestas de la API grabadas, sin red.
Corre con `python3 -m unittest discover Tools/releaseops/tests`."""

import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from rocore import asc_builds  # noqa: E402

FIX = HERE / "fixtures" / "asc_builds"


class FakeClient:
    """Un cliente que sólo sabe leer: registra cada llamada y falla ante cualquier escritura."""

    def __init__(self, name):
        self.page = json.loads((FIX / f"{name}.json").read_text())
        self.calls = []

    def get_all(self, path, params=None):
        self.calls.append(("GET", path, params))
        return self.page["data"], self.page["included"]

    def request(self, method, *args, **kwargs):
        raise AssertionError(f"asc builds sólo lee: {method}")


def free(name, marketing="2.0.0", project_build=0):
    client = FakeClient(name)
    return asc_builds.next_free(asc_builds.fetch(client, "app"), marketing, project_build), client


class NextFreeTests(unittest.TestCase):
    def test_no_builds_of_the_version_gives_5(self):
        self.assertEqual(free("sin_2_0_0")[0], 5)

    def test_with_the_5_uploaded_gives_6(self):
        self.assertEqual(free("con_el_5")[0], 6)

    def test_a_7_processing_gives_8_and_other_versions_do_not_count(self):
        self.assertEqual(free("con_7_procesando")[0], 8)

    def test_project_yml_wins_when_it_is_higher(self):
        self.assertEqual(free("con_el_5", project_build=9)[0], 9)

    def test_project_yml_lower_does_not_lower_it(self):
        self.assertEqual(free("con_el_5", project_build=5)[0], 6)

    def test_no_builds_at_all_gives_5(self):
        self.assertEqual(asc_builds.next_free([], "2.0.0"), 5)


class FetchTests(unittest.TestCase):
    def test_only_one_get_filtered_by_app(self):
        _, client = free("con_el_5")
        self.assertEqual([c[:2] for c in client.calls], [("GET", "/v1/builds")])
        self.assertEqual(client.calls[0][2]["filter[app]"], "app")

    def test_the_newest_upload_comes_first_with_its_version(self):
        builds = asc_builds.fetch(FakeClient("con_7_procesando"), "app")
        self.assertEqual([(b.marketing, b.build, b.state) for b in builds],
                         [("2.0.0", "7", "PROCESSING"), ("2.0.0", "5", "VALID"), ("1.9.0", "9", "VALID")])

    def test_render_ends_with_the_next_free_line(self):
        builds = asc_builds.fetch(FakeClient("con_el_5"), "app")
        text = asc_builds.render(builds, "2.0.0", 6)
        self.assertIn("2.0.0", text)
        self.assertTrue(text.endswith("próximo build libre para 2.0.0: 6"))


if __name__ == "__main__":
    unittest.main()
