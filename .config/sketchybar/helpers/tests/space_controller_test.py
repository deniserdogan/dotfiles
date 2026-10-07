"""Read-only renderer regressions. No native desktops are created or deleted."""
import json
import os
from pathlib import Path
import subprocess
import unittest

CONTROLLER = Path(__file__).resolve().parents[1] / "space_controller"
CONFIG_ROOT = Path(__file__).resolve().parents[3]

def desktop(sid, index, slot, display=1, fullscreen=False):
    return {"id": sid, "index": index, "label": f"slot.{slot}",
            "display": display, "is-visible": index == 1,
            "is-native-fullscreen": fullscreen}

def plan(spaces, windows):
    output = subprocess.check_output([CONTROLLER, "--plan"], input=json.dumps(
        {"spaces": spaces, "windows": windows}).encode(),
        env={**os.environ, "DOTFILES_CONFIG_DIR": str(CONFIG_ROOT)})
    return {row["id"]: row for row in json.loads(output)}

class SpaceRendererTests(unittest.TestCase):
    def test_middle_delete_preserves_identity_and_branded_icons(self):
        before = plan([desktop(10, 1, 1), desktop(20, 2, 2), desktop(130, 3, 3)],
                      [{"space": 1, "app": "Ghostty"}, {"space": 2, "app": "INCY"},
                       {"space": 3, "app": "Podcasts"}])
        after = plan([desktop(10, 1, 1), desktop(130, 2, 2)],
                     [{"space": 1, "app": "Ghostty"}, {"space": 2, "app": "Podcasts"}])
        self.assertEqual(set(after), {10, 130})
        self.assertEqual(after[130]["label"], before[130]["label"])
        self.assertEqual(after[130]["number"], "2")
        self.assertEqual(after[130]["index"], 2)

    def test_multiple_new_empty_desktops_have_a_compact_desktop_icon(self):
        rows = plan([desktop(1001, 5, 5), desktop(1002, 6, 6), desktop(1003, 7, 7)], [])
        self.assertEqual([r["number"] for r in rows.values()], ["5", "6", "7"])
        for row in rows.values():
            self.assertEqual(row["label"], ":desktop:")
            self.assertEqual(row["labelWidth"], 23)
            self.assertEqual(row["width"], 40)

    def test_first_app_replaces_empty_icon_without_a_geometry_jump(self):
        empty = plan([desktop(130, 2, 2)], [])[130]
        occupied = plan([desktop(130, 2, 2)], [{"space": 2, "app": "Ghostty"}])[130]
        self.assertEqual(empty["label"], ":desktop:")
        self.assertEqual(occupied["label"], ":ghostty:")
        self.assertEqual(empty["width"], occupied["width"])

    def test_stack_badge_preserves_middle_dot_and_room_for_text(self):
        rows = plan([desktop(1000, 2, 2)],
                    [{"space": 2, "app": "Ghostty", "stack-index": 1},
                     {"space": 2, "app": "Ghostty", "stack-index": 2}])
        self.assertEqual(rows[1000]["number"], "2·2")
        self.assertGreater(rows[1000]["iconWidth"], 17)
        self.assertEqual(rows[1000]["label"], ":ghostty:")

    def test_monitor_move_keeps_identity_and_global_slot(self):
        rows = plan([desktop(130, 4, 1, display=3), desktop(140, 1, 2, display=1)], [])
        self.assertEqual(rows[130]["slot"], "1")
        self.assertEqual(rows[130]["display"], 3)
        self.assertEqual(rows[140]["slot"], "2")

    def test_native_fullscreen_desktops_are_not_numbered_pills(self):
        rows = plan([desktop(10, 1, 1), desktop(11, 2, 2, fullscreen=True)], [])
        self.assertEqual(set(rows), {10})

if __name__ == "__main__":
    unittest.main()
