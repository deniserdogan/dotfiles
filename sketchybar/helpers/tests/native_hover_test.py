"""Opt-in live hover regressions; never focus, create or delete a desktop.

Run with RICE_LIVE_TESTS=1 while SketchyBar is running and the pointer is off
the bar. Requires an existing desktop with at least two different apps.
"""
import json
import os
from pathlib import Path
import subprocess
import time
import unittest

BAR = "/opt/homebrew/bin/sketchybar"
ROOT = Path(__file__).resolve().parents[3]


def bar(*args):
    return subprocess.check_output([BAR, *args], timeout=3)


@unittest.skipUnless(os.environ.get("RICE_LIVE_TESTS") == "1", "opt-in live bar test")
class NativeHoverTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        plan = json.loads(Path(f"/tmp/sketchybar_space_plan_{os.getuid()}.json").read_text())
        candidates = [row for row in plan if row["appCount"] > 1]
        if not candidates:
            raise unittest.SkipTest("needs an existing multi-app desktop")
        row = max(candidates, key=lambda item: item["visible"])
        cls.owner = f'space.{row["id"]}'
        cls.child = f'space_app.{row["id"]}.1'
        cls.group = f'space_group.{row["id"]}'
        cls.app_count = row["appCount"]

    def event(self, item, event):
        bar("--trigger", "native_hover_test", f"ITEM={item}", f"EVENT={event}")

    def width(self):
        return json.loads(bar("--query", self.child))["geometry"]["width"]

    def wait_width(self, expected):
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            if self.width() == expected:
                return
            time.sleep(0.005)
        self.fail(f"logo width did not settle at {expected}")

    def sample_widths(self, duration=0.25):
        samples = []
        deadline = time.monotonic() + duration
        while time.monotonic() < deadline:
            samples.append(self.width())
        return samples

    def setUp(self):
        self.event("", "mouse.exited.global")
        self.wait_width(18)
        self.event(self.owner, "mouse.entered")
        self.wait_width(21)

    def tearDown(self):
        self.event("", "mouse.exited.global")
        self.wait_width(18)

    def assert_animated_collapse(self, samples):
        self.assertTrue({19, 20}.intersection(samples), f"no intermediate width: {samples}")
        self.assertEqual(samples[-1], 18)

    def test_individual_exit_collapses_without_leaving_the_bar(self):
        self.event(self.owner, "mouse.exited")
        self.assert_animated_collapse(self.sample_widths())

    def test_crossing_sibling_logos_does_not_collapse(self):
        bar("--trigger", "native_hover_test", f"ITEM={self.owner}", "EVENT=mouse.exited",
            "--trigger", "native_hover_test", f"ITEM={self.child}", "EVENT=mouse.entered")
        self.assertEqual(set(self.sample_widths()), {21})
        self.event(self.child, "mouse.exited")
        self.wait_width(18)

    def test_stale_exit_does_not_close_the_newer_hover(self):
        self.event(self.child, "mouse.entered")
        self.event(self.owner, "mouse.exited")
        self.assertEqual(set(self.sample_widths()), {21})

    def test_reentering_same_logo_cancels_pending_exit(self):
        bar("--trigger", "native_hover_test", f"ITEM={self.owner}", "EVENT=mouse.exited",
            "--trigger", "native_hover_test", f"ITEM={self.owner}", "EVENT=mouse.entered")
        self.assertEqual(set(self.sample_widths()), {21})

    def test_space_change_event_animates_collapse(self):
        bar("--trigger", "space_change")
        self.assert_animated_collapse(self.sample_widths())

    def test_last_logo_has_internal_clearance_in_both_states(self):
        for opened in (True, False):
            if not opened:
                self.event("", "mouse.exited.global")
                self.wait_width(18)
            last = self.app_count - 1 if opened else min(self.app_count, 3) - 1
            item = self.owner.replace("space.", "space_app.") + f".{last}"
            group = json.loads(bar("--query", self.group))["bounding_rects"]
            logo = json.loads(bar("--query", item))["bounding_rects"]
            for display, rect in group.items():
                end = rect["origin"][0] + rect["size"][0]
                logo_end = logo[display]["origin"][0] + logo[display]["size"][0]
                self.assertGreaterEqual(end - logo_end, 4)

    def test_renderer_refresh_does_not_cancel_native_collapse(self):
        process = subprocess.Popen(["/bin/sh", str(ROOT / "yabai/scripts/space_controller.sh"),
                                    "--refresh", "--force"], stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE)
        try:
            samples = self.sample_widths(0.6)
            stdout, stderr = process.communicate(timeout=3)
            self.assertEqual(process.returncode, 0, (stdout, stderr))
            self.assert_animated_collapse(samples)
            for item in (self.owner, self.child):
                state = json.loads(bar("--query", item))
                self.assertEqual(state["geometry"]["background"]["drawing"], "off")
            state = json.loads(bar("--query", self.group))
            self.assertEqual(state["geometry"]["background"]["drawing"], "on")
        finally:
            if process.poll() is None:
                process.terminate()
                process.communicate(timeout=3)


if __name__ == "__main__":
    unittest.main()
