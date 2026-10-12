import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import skadnetwork  # noqa: E402

PLIST = """<plist version="1.0">
<dict>
\t<!-- un comentario que no se puede perder -->
\t<key>SKAdNetworkItems</key>
\t<array>
\t\t<dict>
\t\t\t<key>SKAdNetworkIdentifier</key>
\t\t\t<string>cstr6suwn9.skadnetwork</string>
\t\t</dict>
\t</array>
</dict>
</plist>
"""


class SKAdNetworkTests(unittest.TestCase):
    def test_saca_los_ids_de_cualquier_forma_y_en_minuscula(self):
        texto = '{"ids": [{"skadnetwork_id": "V9WTTPBFK9.skadnetwork"}], "x": "n38lu8286q.skadnetwork"}'
        self.assertEqual(skadnetwork.ids_en(texto), ["v9wttpbfk9.skadnetwork", "n38lu8286q.skadnetwork"])

    def test_la_union_conserva_el_orden_de_los_que_estaban_y_ordena_los_nuevos(self):
        self.assertEqual(
            skadnetwork.union(["b.skadnetwork", "a.skadnetwork"], ["c.skadnetwork", "a.skadnetwork", "0.skadnetwork"]),
            ["b.skadnetwork", "a.skadnetwork", "0.skadnetwork", "c.skadnetwork"],
        )

    def test_reescribe_solo_el_array_y_es_idempotente(self):
        ids = ["cstr6suwn9.skadnetwork", "v9wttpbfk9.skadnetwork"]
        una = skadnetwork.reescribir(PLIST, ids)
        self.assertIn("<!-- un comentario que no se puede perder -->", una)
        self.assertEqual(skadnetwork.ids_en(una), ids)
        self.assertEqual(skadnetwork.reescribir(una, ids), una)


if __name__ == "__main__":
    unittest.main()
