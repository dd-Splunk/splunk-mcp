"""Unit tests for workshop mode helpers (no Splunk SDK, no Docker)."""

from __future__ import annotations

import json
import sys
import types
import unittest
from pathlib import Path

BIN = Path(__file__).resolve().parents[1] / "SA-S4R" / "bin"


def _install_splunk_stubs() -> None:
    if "splunk.persistconn.application" in sys.modules:
        return
    splunk = types.ModuleType("splunk")
    rest = types.ModuleType("splunk.rest")
    persistconn = types.ModuleType("splunk.persistconn")
    application = types.ModuleType("splunk.persistconn.application")

    class PersistentServerConnectionApplication:
        def __init__(self, *args, **kwargs) -> None:  # noqa: ANN002, ANN003
            pass

    application.PersistentServerConnectionApplication = PersistentServerConnectionApplication

    def _no_rest(*args, **kwargs):  # noqa: ANN002, ANN003, ARG001
        raise RuntimeError("splunk.rest.simpleRequest must not run in unit tests")

    rest.simpleRequest = _no_rest
    sys.modules["splunk"] = splunk
    sys.modules["splunk.rest"] = rest
    sys.modules["splunk.persistconn"] = persistconn
    sys.modules["splunk.persistconn.application"] = application


_install_splunk_stubs()
sys.path.insert(0, str(BIN))

import s4r_eventgen_mode as eventgen  # noqa: E402
import s4r_workshop_mode as workshop  # noqa: E402


class ModeMappingTests(unittest.TestCase):
    def test_mode_from_disabled(self) -> None:
        self.assertEqual(workshop.mode_from_disabled(True), "infrastructure")
        self.assertEqual(workshop.mode_from_disabled(False), "threat")

    def test_disabled_from_mode(self) -> None:
        self.assertTrue(workshop.disabled_from_mode("infrastructure"))
        self.assertFalse(workshop.disabled_from_mode("threat"))
        with self.assertRaises(ValueError):
            workshop.disabled_from_mode("both")


class PayloadParseTests(unittest.TestCase):
    def test_dict_passthrough(self) -> None:
        self.assertEqual(
            workshop.WorkshopModeHandler._parse_payload({"mode": "threat"}),
            {"mode": "threat"},
        )

    def test_json_string(self) -> None:
        raw = json.dumps({"mode": "infrastructure"})
        self.assertEqual(
            workshop.WorkshopModeHandler._parse_payload(raw),
            {"mode": "infrastructure"},
        )

    def test_invalid_or_empty(self) -> None:
        self.assertEqual(workshop.WorkshopModeHandler._parse_payload(None), {})
        self.assertEqual(workshop.WorkshopModeHandler._parse_payload(""), {})
        self.assertEqual(workshop.WorkshopModeHandler._parse_payload("not-json"), {})
        self.assertEqual(workshop.WorkshopModeHandler._parse_payload("[1]"), {})
        self.assertEqual(workshop.WorkshopModeHandler._parse_payload(12), {})


class EventgenPayloadParseTests(unittest.TestCase):
    def test_content_object_disabled(self) -> None:
        payload = {"entry": [{"content": {"disabled": "true"}}]}
        self.assertTrue(eventgen.disabled_from_properties_payload(payload))
        payload = {"entry": [{"content": {"disabled": False}}]}
        self.assertFalse(eventgen.disabled_from_properties_payload(payload))

    def test_content_scalar_and_raw_body(self) -> None:
        self.assertTrue(eventgen.disabled_from_properties_payload({"entry": [{"content": "1"}]}))
        self.assertFalse(eventgen.disabled_from_body("false"))
        self.assertTrue(eventgen.disabled_from_body(json.dumps({"entry": [{"content": True}]})))

    def test_missing_stanza_returns_none(self) -> None:
        self.assertIsNone(eventgen.disabled_from_properties_payload({}))
        self.assertIsNone(eventgen.disabled_from_properties_payload({"entry": []}))
        self.assertIsNone(eventgen.disabled_from_body(""))
        self.assertIsNone(eventgen.disabled_from_properties_payload({"entry": [{"content": {}}]}))

    def test_unexpected_value_raises(self) -> None:
        with self.assertRaises(eventgen.EventgenConfigError):
            eventgen.disabled_from_body("maybe")


class ReloadEventgenTests(unittest.TestCase):
    def setUp(self) -> None:
        self.calls: list[str] = []
        self._orig_post = workshop._post_eventgen
        self._orig_sleep = workshop.time.sleep
        workshop.time.sleep = lambda _seconds: None

    def tearDown(self) -> None:
        workshop._post_eventgen = self._orig_post
        workshop.time.sleep = self._orig_sleep

    def _stub(self, results: list[str]) -> None:
        def fake(_session_key: str, endpoint: str) -> str:
            self.calls.append(endpoint)
            return results.pop(0)

        workshop._post_eventgen = fake

    def test_success(self) -> None:
        self._stub(["", ""])
        self.assertEqual(workshop.reload_eventgen("k"), (True, "", ""))
        self.assertEqual(self.calls, [workshop.EVENTGEN_DISABLE_URL, workshop.EVENTGEN_ENABLE_URL])

    def test_disable_fails_suggests_restart(self) -> None:
        self._stub(["disable: HTTP 500"])
        ok, error, hint = workshop.reload_eventgen("k")
        self.assertFalse(ok)
        self.assertEqual(error, "disable: HTTP 500")
        self.assertEqual(hint, workshop.HINT_RELOAD_FAILED)
        self.assertEqual(len(self.calls), 1)

    def test_enable_retries_then_succeeds(self) -> None:
        self._stub(["", "enable: HTTP 500", ""])
        self.assertEqual(workshop.reload_eventgen("k"), (True, "", ""))
        self.assertEqual(len(self.calls), 3)

    def test_enable_exhausted_reports_left_disabled(self) -> None:
        self._stub([""] + ["enable: HTTP 500"] * workshop.ENABLE_ATTEMPTS)
        ok, error, hint = workshop.reload_eventgen("k")
        self.assertFalse(ok)
        self.assertEqual(error, "enable: HTTP 500")
        self.assertEqual(hint, workshop.HINT_LEFT_DISABLED)
        self.assertEqual(len(self.calls), 1 + workshop.ENABLE_ATTEMPTS)


if __name__ == "__main__":
    unittest.main()
