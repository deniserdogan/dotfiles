"""Read-only catalog checks; never change the live appearance."""
import json
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[3]
THEME = ROOT / "sketchybar/helpers/native_theme"
CATALOG = json.loads((ROOT / "sketchybar/themes/catalog.json").read_text())
GHOSTTY = Path("/Applications/Ghostty.app/Contents/Resources/ghostty/themes")


class ThemeCatalogTests(unittest.TestCase):
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
        import tempfile
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
