"""Read-only catalog checks; never change the live appearance."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
THEME = ROOT / "sketchybar/helpers/native_theme"
CATALOG = json.loads((ROOT / "sketchybar/themes/catalog.json").read_text())
GHOSTTY = Path("/Applications/Ghostty.app/Contents/Resources/ghostty/themes")


class ThemeCatalogTests(unittest.TestCase):
    def test_all_themes_are_stably_grouped_dark_then_light(self):
        listed = json.loads(subprocess.check_output([THEME, "--list"]))
        expected = [row["id"] for mode in ("dark", "light")
                    for row in CATALOG if row["mode"] == mode]
        self.assertEqual([row["id"] for row in listed], expected)

    def test_independent_theme_memory_survives_restart_and_write_failures(self):
        # Compile the production persistence helpers against isolated fixtures.
        # No theme service, appearance change, or real preference file is used.
        with tempfile.TemporaryDirectory(prefix="rice-selection-test-", dir="/private/tmp") as temporary:
            executable = Path(temporary) / "selection_test"
            subprocess.run(["xcrun", "clang", "-O2", "-Wall", "-Wextra", "-fobjc-arc",
                            str(Path(__file__).with_name("theme_selection_test.m")),
                            "-framework", "Foundation", "-o", str(executable)], check=True)
            subprocess.run([executable, ROOT / "sketchybar", temporary], check=True)

    def test_expanded_catalog_prioritizes_light_themes(self):
        self.assertEqual(len({row["id"] for row in CATALOG}), len(CATALOG))
        self.assertGreaterEqual(len(CATALOG), 18)
        self.assertGreaterEqual(sum(row["mode"] == "light" for row in CATALOG), 10)
        self.assertEqual({row["mode"] for row in CATALOG}, {"light", "dark"})

    def test_every_palette_has_the_same_validated_roles(self):
        required = {"BAR_COLOR", "BAR_BORDER", "ITEM_BG", "ITEM_BG_STRONG", "ITEM_BORDER",
                    "TEXT", "ACTIVE_TEXT", "SUBTEXT", "MUTED", "BLUE", "TEAL", "GREEN",
                    "GREEN_FILL", "YELLOW", "PEACH", "RED", "MAUVE"}
        for row in CATALOG:
            with self.subTest(theme=row["id"]):
                palette = json.loads(subprocess.check_output([THEME, "--plan", row["id"]]))
                self.assertEqual(set(palette), required)
                for value in palette.values():
                    self.assertRegex(value, r"^0x[0-9a-fA-F]{8}$")

    def test_borders_follow_every_theme_without_glow_or_fill(self):
        styles = set()
        for row in CATALOG:
            with self.subTest(theme=row["id"]):
                palette = json.loads(subprocess.check_output([THEME, "--plan", row["id"]]))
                arguments = subprocess.check_output([THEME, "--border-args", row["id"]], text=True).splitlines()
                options = dict(argument.split("=", 1) for argument in arguments)
                self.assertEqual(set(options), {"style", "width", "hidpi", "background_color", "active_color", "inactive_color"})
                self.assertEqual(options["style"], "round")
                self.assertEqual(options["width"], "2.0")
                self.assertEqual(options["hidpi"], "on")
                self.assertEqual(options["background_color"], "0x00000000")
                blue, mauve = int(palette["BLUE"][4:], 16), int(palette["MAUVE"][4:], 16)
                mixed = sum(int(((blue >> shift) & 255)*.60 + ((mauve >> shift) & 255)*.40) << shift
                            for shift in (0, 8, 16))
                self.assertEqual(options["active_color"],
                                 f"gradient(top_left=0xff{blue:06x},bottom_right=0xee{mixed:06x})")
                alpha = "24" if row["mode"] == "dark" else "1c"
                self.assertEqual(options["inactive_color"], f"0x{alpha}{palette['TEXT'][4:]}")
                styles.add(options["active_color"])
        self.assertEqual(len(styles), len(CATALOG))
        self.assertEqual(subprocess.run([THEME, "--border-args", "unknown-theme"], capture_output=True).returncode, 2)

    def test_border_startup_matches_live_options(self):
        # The borders executable is replaced by a fixture: no daemon is contacted.
        with tempfile.TemporaryDirectory(prefix="rice-border-test-", dir="/private/tmp") as temporary:
            home = Path(temporary)
            (home / ".config").symlink_to(ROOT, target_is_directory=True)
            binary = home / "bin"
            binary.mkdir()
            mock = binary / "borders"
            mock.write_text("#!/usr/bin/env python3\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n")
            mock.chmod(0o755)
            for mode in ("dark", "light"):
                expected = subprocess.check_output([THEME, "--border-args", mode], text=True).splitlines()
                actual = subprocess.check_output(["/bin/bash", ROOT / "borders/bordersrc"], text=True,
                    env={**os.environ, "HOME": str(home), "THEME_MODE": mode,
                         "PATH": f"{binary}:{os.environ['PATH']}"})
                self.assertEqual(json.loads(actual), expected)

    @unittest.skipUnless(GHOSTTY.is_dir(), "Ghostty resources unavailable")
    def test_every_terminal_theme_is_installed(self):
        for row in CATALOG:
            self.assertTrue((GHOSTTY / row["ghostty"]).is_file(), row["ghostty"])

    def test_unknown_theme_is_rejected_without_mutation(self):
        self.assertEqual(subprocess.run([THEME, "--select", "unknown-theme"], capture_output=True).returncode, 2)

    @unittest.skipUnless((ROOT / ".git").exists(), "requires a Git checkout")
    def test_personal_assets_and_choices_are_ignored(self):
        paths = ["rice/logos/custom.svg", "rice/wallpapers/photo.jpg", "rice/personalization.json"]
        ignored = subprocess.check_output(["git", "-C", ROOT, "check-ignore", *paths], text=True).splitlines()
        self.assertEqual(ignored, paths)
        self.assertEqual(subprocess.check_output(["git", "-C", ROOT, "ls-files", "--", "rice"], text=True), "")

    def test_malformed_catalog_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "themes"
            path.mkdir()
            # Test fixtures, not configuration edits.
            (path / "catalog.json").write_text('[{"id":"bad;command"}]')
            result = subprocess.run([THEME, "--list"], capture_output=True,
                                    env={**os.environ, "CONFIG_DIR": directory})
            self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
