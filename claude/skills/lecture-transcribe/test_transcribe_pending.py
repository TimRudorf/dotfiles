#!/usr/bin/env python3
"""Unit-Tests für transcribe_pending.py — Queue-Anbindung + Quellauflösung.

Browser (playwright) + ASR (transcribe.py) sind gemockt → kein Netz, kein API-Spend.
    python3 -m unittest test_transcribe_pending -v
"""
import json
import tempfile
import unittest
from pathlib import Path

import transcribe_pending as tp


class TestClassify(unittest.TestCase):
    def test_panopto_viewer(self):
        self.assertEqual(
            tp.classify_resolved_url(
                "https://tu-darmstadt.cloud.panopto.eu/Panopto/Pages/Embed.aspx?id=64311577-06c3-458f-a6e2-af3801217dfb&foo=1"),
            ("panopto", "64311577-06c3-458f-a6e2-af3801217dfb"))

    def test_moodleload_mp4(self):
        url = "https://moodleload.hrz.tu-darmstadt.de/FB18_RMR/SDRT3/VL3.mp4"
        self.assertEqual(tp.classify_resolved_url(url), ("direct", url))

    def test_moodleload_html_to_mp4(self):
        url = "https://moodleload.hrz.tu-darmstadt.de/a/EoE_6.html"
        self.assertEqual(tp.classify_resolved_url(url),
                         ("direct", "https://moodleload.hrz.tu-darmstadt.de/a/EoE_6.mp4"))

    def test_unknown_none(self):
        self.assertEqual(tp.classify_resolved_url("https://example.com/page"), (None, None))
        self.assertEqual(tp.classify_resolved_url(""), (None, None))


class TestIdentity(unittest.TestCase):
    def test_lti_cmid(self):
        self.assertEqual(tp._identity({"modname": "lti", "cmid": 1630442, "url": "v"}), "cmid:1630442")

    def test_moodleload_url(self):
        self.assertEqual(tp._identity({"source": "camtasia", "cmid": 1, "url": "https://m/x.mp4"}),
                         "https://m/x.mp4")


class TestBuildItem(unittest.TestCase):
    def setUp(self):
        self._orig_guid = tp.resolve_panopto_guid
        self._orig_url = tp.resolve_url_module

    def tearDown(self):
        tp.resolve_panopto_guid = self._orig_guid
        tp.resolve_url_module = self._orig_url

    def test_lti_entry_resolves_panopto(self):
        tp.resolve_panopto_guid = lambda cmid: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        item, err = tp.build_item("dimm", {"cmid": 100, "modname": "lti", "name": "Guest Lecture"}, set())
        self.assertIsNone(err)
        self.assertEqual(item["source"], "panopto")
        self.assertEqual(item["ref"], "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        self.assertEqual(item["lang"], "en")  # dimm = englisch

    def test_legacy_url_entry_resolves_moodleload(self):
        """sdrt3-Altzeintrag (modname=url, kein source) → Redirect-Resolve auf moodleload-MP4."""
        tp.resolve_url_module = lambda u: ("direct", "https://moodleload.hrz.tu-darmstadt.de/x/VL3.mp4")
        item, err = tp.build_item(
            "sdrt3",
            {"cmid": 1611720, "modname": "url", "name": "Aufzeichnung Kapitel 3.2",
             "url": "https://moodle.tu-darmstadt.de/mod/url/view.php?id=1611720"}, set())
        self.assertIsNone(err)
        self.assertEqual(item["source"], "direct")
        self.assertEqual(item["ref"], "https://moodleload.hrz.tu-darmstadt.de/x/VL3.mp4")

    def test_new_camtasia_entry_direct(self):
        item, err = tp.build_item("international-economics", {
            "cmid": 1770490, "modname": "page", "source": "camtasia", "auth": "cas",
            "name": "EoE_6.mp4", "url": "https://moodleload.hrz.tu-darmstadt.de/a/EoE_6.mp4"}, set())
        self.assertIsNone(err)
        self.assertEqual(item["source"], "direct")
        self.assertEqual(item["ref"], "https://moodleload.hrz.tu-darmstadt.de/a/EoE_6.mp4")

    def test_unresolvable_url_returns_error(self):
        tp.resolve_url_module = lambda u: (None, None)
        item, err = tp.build_item("sdrt3", {"cmid": 1, "modname": "url", "name": "x",
                                            "url": "https://moodle/x"}, set())
        self.assertIsNone(item)
        self.assertIn("url-Resolve", err)


class TestQueueIO(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self._orig = tp.VAULT_LERNPLAN
        tp.VAULT_LERNPLAN = Path(self.tmp.name)

    def tearDown(self):
        tp.VAULT_LERNPLAN = self._orig
        self.tmp.cleanup()

    def _make_queue(self, modul, entries):
        d = Path(self.tmp.name) / modul / "transkripte"
        d.mkdir(parents=True)
        (d / "_pending.json").write_text(json.dumps({"pending": entries}))
        return d / "_pending.json"

    def test_load_queues_filters_and_skips_empty(self):
        self._make_queue("dimm", [{"cmid": 1, "name": "a", "modname": "lti", "url": "u1"}])
        self._make_queue("sdrt3", [])  # leer → nicht gelistet
        self._make_queue("thermo", [{"cmid": 2, "name": "b", "modname": "lti", "url": "u2"}])
        all_q = tp.load_queues(None)
        self.assertEqual({m for m, _, _ in all_q}, {"dimm", "thermo"})
        only = tp.load_queues(["dimm"])
        self.assertEqual([m for m, _, _ in only], ["dimm"])

    def test_remove_from_queue_by_identity(self):
        p = self._make_queue("sdrt3", [
            {"cmid": 1, "name": "a", "source": "camtasia", "url": "https://m/a.mp4"},
            {"cmid": 1, "name": "b", "source": "camtasia", "url": "https://m/b.mp4"},
        ])
        tp.remove_from_queue(p, {"https://m/a.mp4"})
        kept = json.loads(p.read_text())["pending"]
        self.assertEqual(len(kept), 1)
        self.assertEqual(kept[0]["url"], "https://m/b.mp4")


if __name__ == "__main__":
    unittest.main()
