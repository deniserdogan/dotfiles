"""Explicit opt-in integration check. Restores the original theme and choices.

RICE_THEME_LIVE_TESTS=1 python3 theme_live_test.py
Temporarily exercises the catalog; never creates or moves a desktop.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[3]
THEME = ROOT / "sketchybar/helpers/native_theme"
PANEL = ROOT / "sketchybar/helpers/RicePanel.app/Contents/MacOS/RicePanel"
BAR = "/opt/homebrew/bin/sketchybar"


def wait_for(predicate, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            result = predicate()
            if result:
                return result
        except (OSError, ValueError, KeyError, subprocess.SubprocessError):
            pass
        time.sleep(0.025)
    raise AssertionError("live state did not settle")


@unittest.skipUnless(os.environ.get("RICE_THEME_LIVE_TESTS") == "1", "opt-in appearance test")
class ThemeLiveTests(unittest.TestCase):
    def test_appearance_toggle_restores_both_remembered_themes(self):
        state_path = Path(f"/tmp/rice_theme_{os.getuid()}.json")
        preferences = ROOT / "rice/theme-selection.json"
        saved = json.loads(preferences.read_text())
        original = json.loads(state_path.read_text())["id"]
        catalog = {row["id"]: row for row in json.loads(subprocess.check_output([THEME, "--list"]))}

        def matching(identifier):
            if json.loads(state_path.read_text())["id"] != identifier:
                return False
            palette = json.loads(subprocess.check_output([THEME, "--plan", identifier]))
            actual = json.loads(subprocess.check_output([BAR, "--query", "bar"]))
            return actual["color"] == palette["BAR_COLOR"] and (ROOT / "ghostty/theme-mode").read_text() == f'theme = {catalog[identifier]["ghostty"]}\n'

        try:
            for mode in ("dark", "light"):
                subprocess.run([THEME, "--select", saved[mode]], check=True)
                wait_for(lambda: matching(saved[mode]))
            for mode in ("dark", "light"):
                subprocess.run([THEME, "--toggle"], check=True)
                wait_for(lambda: matching(saved[mode]))
                self.assertEqual(json.loads(preferences.read_text()), saved)
            # --sync reloads preferences from disk, as a fresh service does.
            subprocess.run([THEME, "--sync"], check=True)
            wait_for(lambda: matching(saved["light"]))
        finally:
            subprocess.run([THEME, "--select", original], check=True)
            wait_for(lambda: matching(original))
        self.assertEqual(json.loads(preferences.read_text()), saved)

    def test_all_themes_sync_bar_editor_terminal_and_gallery(self):
        state_path = Path(f"/tmp/rice_theme_{os.getuid()}.json")
        preferences = ROOT / "rice/theme-selection.json"
        saved_preferences = json.loads(preferences.read_text())
        original_state = json.loads(state_path.read_text())
        original = original_state["id"]
        catalog = json.loads(subprocess.check_output([THEME, "--list"]))
        with tempfile.TemporaryDirectory(prefix="rice-theme-test-", dir="/private/tmp") as temporary:
            socket = str(Path(temporary) / "nvim.sock")
            editor = subprocess.Popen(["nvim", "--headless", "--listen", socket],
                                      stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            def editor_state():
                expression = 'json_encode([g:colors_name, &background, nvim_get_hl(0, {"name":"Normal","link":v:false})])'
                return json.loads(subprocess.check_output(["nvim", "--server", socket,
                    "--remote-expr", expression], stderr=subprocess.DEVNULL, timeout=2))
            try:
                wait_for(editor_state)
                subprocess.run([PANEL, "--themes"], check=True)
                for theme in catalog:
                    # Stop on service failure instead of cascading through the
                    # remaining catalog with a dead panel.
                    subprocess.run([THEME, "--select", theme["id"]], check=True)
                    wait_for(lambda: json.loads(state_path.read_text())["id"] == theme["id"])
                    palette = json.loads(subprocess.check_output([THEME, "--plan", theme["id"]]))
                    wait_for(lambda: json.loads(subprocess.check_output([BAR, "--query", "bar"]))["color"] == palette["BAR_COLOR"])
                    def matching_editor():
                        state = editor_state()
                        name = "rose-pine" if theme["id"].startswith("rose-pine") else "kanagawa" if theme["id"].startswith("kanagawa") else theme["neovim"]
                        return state if state[0] == name and state[1] == theme["mode"] else None
                    actual = wait_for(matching_editor)
                    self.assertNotIn("bg", actual[2], "Neovim must stay transparent")
                    self.assertEqual((ROOT / "ghostty/theme-mode").read_text(), f'theme = {theme["ghostty"]}\n')
                    probe = Path(temporary) / f'{theme["id"]}.json'
                    subprocess.run([PANEL, "--inspect", str(probe)], check=True)
                    panel = wait_for(lambda: json.loads(probe.read_text()))
                    self.assertEqual(panel["page"], "themes")
                    self.assertEqual([row["id"] for row in panel["themes"] if row["selected"]], [theme["id"]])
            finally:
                try:
                    # Restore through the coordinator, not a competing file
                    # write while its asynchronous commit is still running.
                    other_mode = "light" if original_state["mode"] == "dark" else "dark"
                    for identifier in (saved_preferences[other_mode], original):
                        subprocess.run([THEME, "--select", identifier], check=True)
                        wait_for(lambda: json.loads(state_path.read_text())["id"] == identifier)
                    wait_for(lambda: json.loads(preferences.read_text()) == saved_preferences)
                finally:
                    subprocess.run([PANEL, "--close"], check=False)
                    editor.terminate()
                    try:
                        _, stderr = editor.communicate(timeout=3)
                    except subprocess.TimeoutExpired:
                        editor.kill()
                        _, stderr = editor.communicate()
                    if b"Error in" in stderr or b"Failed to" in stderr:
                        self.fail(stderr.decode(errors="replace"))


if __name__ == "__main__":
    unittest.main()
