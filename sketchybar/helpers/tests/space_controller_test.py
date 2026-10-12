"""Read-only renderer regressions. No native desktops are created or deleted."""
import json
import os
from pathlib import Path
import subprocess
import unittest

CONTROLLER = Path(__file__).resolve().parents[1] / "space_controller"
MOTION = CONTROLLER.with_name("native_motion")
THEME = CONTROLLER.with_name("native_theme")
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

    def test_multiple_apps_use_one_primary_glyph_not_a_concatenated_label(self):
        row = plan([desktop(130, 2, 2)], [
            {"space": 2, "app": "Brave Browser"},
            {"space": 2, "app": "Ghostty", "has-focus": True},
            {"space": 2, "app": "Podcasts"}])[130]
        self.assertEqual(row["label"], ":brave_browser:")
        self.assertEqual(row["appCount"], 3)
        self.assertEqual(len(row["apps"]), 3)
        self.assertEqual(row["labelWidth"], 23)
        self.assertEqual(row["width"], 40)

    def test_app_order_is_stable_across_focus_and_desktop_changes(self):
        windows = [{"space": 2, "app": app, "has-focus": app == "Ghostty"}
                   for app in ("Podcasts", "Ghostty", "Brave Browser")]
        before = plan([desktop(130, 2, 2)], windows)[130]
        for window in windows:
            window["has-focus"] = window["app"] == "Podcasts"
        active = desktop(130, 2, 2)
        active["is-visible"] = True
        after = plan([active], list(reversed(windows)))[130]
        self.assertEqual(before["apps"], after["apps"])
        self.assertEqual(before["label"], after["label"])
        self.assertEqual(before["apps"][0], before["label"])

    def test_multiple_windows_of_one_app_do_not_inflate_the_app_badge(self):
        row = plan([desktop(130, 2, 2)], [
            {"space": 2, "app": "Ghostty"}, {"space": 2, "app": "Ghostty"}])[130]
        self.assertEqual(row["appCount"], 1)

    def expansion(self, count, opened):
        data = {"space": {"id": 130, "apps": [":ghostty:"] * count,
                           "appCount": count, "visible": True}, "open": opened}
        args = json.loads(subprocess.check_output([MOTION, "--plan-expansion"], input=json.dumps(data).encode()))
        items, current = {}, None
        for arg in args:
            if arg == "--set":
                current = None
            elif current is None:
                current = arg
                items.setdefault(current, {})
            else:
                key, value = arg.split("=", 1)
                items[current][key] = value
        return items

    def test_native_expansion_has_spaced_logos_without_individual_tiles(self):
        items = self.expansion(3, True)
        self.assertEqual(items["space_app.130.1"]["width"], "21")
        self.assertEqual(items["space_app.130.1"]["icon.width"], "21")
        self.assertEqual(items["space_app.130.2"]["width"], "21")
        self.assertEqual(items["space_app.130.1"]["background.drawing"], "off")
        self.assertEqual(items["space_more.130"]["width"], "4")
        self.assertEqual(items["space_more.130"]["label.width"], "0")

    def test_native_collapse_keeps_three_separate_logos_visible(self):
        items = self.expansion(3, False)
        for index in (1, 2):
            child = items[f"space_app.130.{index}"]
            self.assertEqual(child["width"], "18")
            self.assertEqual(child["icon.width"], "18")
            self.assertEqual(child["padding_left"], "0")
            self.assertEqual(child["y_offset"], "0")
            self.assertEqual(child["background.drawing"], "off")
            self.assertNotEqual(child["icon.color"], "0x00000000")
        self.assertEqual(items["space_more.130"]["width"], "4")
        self.assertEqual(items["space_more.130"]["label.width"], "0")

    def test_two_apps_are_both_visible_without_an_overflow_badge(self):
        items = self.expansion(2, False)
        self.assertEqual(items["space_app.130.1"]["width"], "18")
        self.assertNotEqual(items["space_app.130.1"]["icon.color"], "0x00000000")
        self.assertEqual(items["space_more.130"]["width"], "4")

    def test_only_apps_beyond_three_are_counted_in_the_compact_badge(self):
        items = self.expansion(4, False)
        self.assertEqual(items["space_more.130"]["label"], "+1")
        self.assertEqual(items["space_more.130"]["width"], "28")
        hidden = items["space_app.130.3"]
        self.assertEqual(hidden["width"], "0")
        self.assertEqual(hidden["icon.width"], "0")
        self.assertEqual(hidden["padding_left"], "0")
        self.assertEqual(hidden["icon.color"], "0x00000000")
        self.assertEqual(hidden["background.drawing"], "off")

    def test_hover_reveals_every_app_even_beyond_the_old_six_app_limit(self):
        items = self.expansion(9, True)
        children = [value for name, value in items.items() if name.startswith("space_app.")]
        self.assertEqual(len(children), 8)
        for child in children:
            self.assertEqual(child["width"], "21")
            self.assertEqual(child["padding_left"], "0")
            self.assertEqual(child["y_offset"], "0")
            self.assertEqual(child["background.drawing"], "off")
        self.assertEqual(items["space_more.130"]["width"], "4")
        self.assertEqual(self.expansion(9, False)["space_more.130"]["label"], "+6")

    def test_internal_end_inset_is_constant_in_both_states(self):
        for count in (2, 3, 4, 9):
            for opened in (False, True):
                badge = self.expansion(count, opened)["space_more.130"]
                self.assertEqual(int(badge["width"]) - int(badge["label.width"]), 4)
                self.assertEqual(badge["background.drawing"], "off")

    def test_hover_adds_only_three_pixels_per_visible_logo(self):
        compact, opened = self.expansion(3, False), self.expansion(3, True)
        for index in (1, 2):
            name = f"space_app.130.{index}"
            self.assertEqual(int(opened[name]["width"]) - int(compact[name]["width"]), 3)

    def test_native_palette_matches_existing_shell_colors(self):
        for mode in ("dark", "light"):
            native = json.loads(subprocess.check_output([THEME, "--plan", mode]))
            names = sorted(native)
            command = 'THEME_MODE="$1"; . "$2"; printf "%s\\n" ' + " ".join('"$' + name + '"' for name in names)
            shell = subprocess.check_output(["/bin/sh", "-c", command, "palette-test", mode,
                                             str(CONFIG_ROOT / "sketchybar/colors.sh")]).decode().splitlines()
            self.assertEqual(native, dict(zip(names, shell)))

if __name__ == "__main__":
    unittest.main()
