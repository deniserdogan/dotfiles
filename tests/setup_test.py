"""Exercise setup in disposable roots with fake tools; never change the desktop."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
CONFIGS = ("borders", "ghostty", "nvim", "sketchybar", "skhd", "yabai")


class SetupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="rice-setup-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.repo = self.root / "checkout with spaces"
        self.config = self.root / "user config"
        self.fonts = self.root / "user fonts"
        self.bin = self.root / "bin"
        self.log = self.root / "tools.log"
        self.make_checkout(self.repo)
        self.bin.mkdir()
        mock = '''#!/bin/sh
printf '%s %s\\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"
case "$(basename "$0")" in
  uname) if [ "$1" = -s ]; then echo Darwin; else echo "${SETUP_TEST_MACHINE:-arm64}"; fi ;;
  brew) if [ "$1" = --prefix ]; then echo /opt/homebrew; fi ;;
  xcode-select) echo /Library/Developer/CommandLineTools ;;
  launchctl) [ "${SETUP_TEST_SERVICES_LOADED:-0}" = 1 ] ;;
esac
'''
        for name in ("uname", "brew", "xcode-select", "launchctl", "yabai", "skhd",
                     "sketchybar", "borders", "jq", "nowplaying-cli", "nvim", "rg", "fd", "lazygit"):
            tool = self.bin / name
            tool.write_text(mock)
            tool.chmod(0o755)
        self.env = dict(os.environ, PATH=f"{self.bin}:/usr/bin:/bin",
                        DOTFILES_CONFIG_DIR=str(self.config), DOTFILES_FONT_DIR=str(self.fonts),
                        SETUP_TEST_LOG=str(self.log))

    def make_checkout(self, repo):
        repo.mkdir(parents=True)
        shutil.copy2(ROOT / "setup.sh", repo / "setup.sh")
        for name in CONFIGS:
            (repo / name).mkdir()
        (repo / "Brewfile").write_text("# fixture\n")
        fonts = repo / "sketchybar/fonts"
        fonts.mkdir()
        (fonts / "rice-app-icons.ttf").write_bytes(b"fixture-font")
        helpers = repo / "sketchybar/helpers"
        helpers.mkdir()
        (helpers / "build.sh").write_text('''#!/bin/sh
set -eu
printf 'build\\n' >> "$SETUP_TEST_LOG"
[ "${SETUP_TEST_BUILD_FAIL:-0}" = 0 ] || exit 42
directory="$(dirname "$0")"
mkdir -p "$directory/RicePanel.app/Contents/MacOS"
for name in native_motion space_controller native_theme RicePanel.app/Contents/MacOS/RicePanel; do
  touch "$directory/$name"
  chmod +x "$directory/$name"
done
''')

    def run_setup(self, *args, ok=True, repo=None):
        result = subprocess.run(["/bin/bash", str((repo or self.repo) / "setup.sh"), *args],
                                env=self.env, text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def calls(self):
        return self.log.read_text() if self.log.exists() else ""

    def test_dry_run_does_not_write_or_execute_plan(self):
        result = self.run_setup("--dry-run", "--start-services")
        self.assertIn("Dry run only", result.stdout)
        self.assertIn("bundle install", result.stdout)
        self.assertFalse(self.config.exists())
        self.assertFalse(self.fonts.exists())
        self.assertNotIn("build\n", self.calls())
        self.assertNotIn("brew ", self.calls())
        self.assertNotIn("yabai ", self.calls())

    def test_fresh_install_and_idempotent_repeat(self):
        self.run_setup()
        for name in CONFIGS:
            self.assertEqual((self.config / name).resolve(), self.repo / name)
        self.assertEqual((self.fonts / "rice-app-icons.ttf").read_bytes(), b"fixture-font")
        for name in ("wallpapers", "logos", "cache"):
            self.assertTrue((self.config / "rice" / name).is_dir())
        self.assertIn("--no-upgrade", self.calls())
        self.run_setup("--skip-packages")
        self.assertEqual(list(self.config.glob("dotfiles-backup.*")), [])
        self.assertNotIn("--start-service", self.calls())
        self.assertNotIn("services restart", self.calls())

    def test_preserves_configs_broken_links_font_and_personal_assets(self):
        (self.config / "nvim").mkdir(parents=True)
        (self.config / "nvim/private.lua").write_text("keep me")
        (self.config / "ghostty").symlink_to(self.root / "nonexistent")
        (self.config / "rice/logos").mkdir(parents=True)
        personal = self.config / "rice/logos/private.svg"
        personal.write_text("personal artwork")
        self.fonts.mkdir()
        (self.fonts / "rice-app-icons.ttf").write_bytes(b"older-font")
        self.run_setup("--skip-packages")
        backups = list(self.config.glob("dotfiles-backup.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "nvim/private.lua").read_text(), "keep me")
        self.assertTrue((backups[0] / "ghostty").is_symlink())
        self.assertEqual((backups[0] / "rice-app-icons.ttf").read_bytes(), b"older-font")
        self.assertEqual(personal.read_text(), "personal artwork")

    def test_checkout_at_config_root_is_not_moved_or_linked(self):
        self.env["DOTFILES_CONFIG_DIR"] = str(self.repo)
        self.run_setup("--skip-packages")
        for name in CONFIGS:
            self.assertFalse((self.repo / name).is_symlink())
        self.assertEqual(list(self.repo.glob("dotfiles-backup.*")), [])

    def test_build_failure_leaves_existing_configs_untouched(self):
        (self.config / "nvim").mkdir(parents=True)
        original = self.config / "nvim/original"
        original.write_text("unchanged")
        self.env["SETUP_TEST_BUILD_FAIL"] = "1"
        self.run_setup("--skip-packages", ok=False)
        self.assertEqual(original.read_text(), "unchanged")
        self.assertFalse(self.fonts.exists())
        self.assertFalse((self.config / "ghostty").exists())
        self.assertEqual(list(self.config.glob("dotfiles-backup.*")), [])

    def test_services_are_explicitly_opt_in(self):
        self.run_setup("--skip-packages", "--start-services")
        self.assertIn("yabai --start-service", self.calls())
        self.assertIn("skhd --start-service", self.calls())
        self.assertIn("brew services restart sketchybar", self.calls())
        self.assertNotIn("sudo", self.calls())

    def test_loaded_services_are_restarted_instead_of_started_twice(self):
        self.env["SETUP_TEST_SERVICES_LOADED"] = "1"
        self.run_setup("--skip-packages", "--start-services")
        self.assertIn("yabai --restart-service", self.calls())
        self.assertIn("skhd --restart-service", self.calls())
        self.assertNotIn("--start-service", self.calls())

    def test_dry_run_preserves_conflicting_config(self):
        (self.config / "nvim").mkdir(parents=True)
        original = self.config / "nvim/original"
        original.write_text("unchanged")
        self.run_setup("--dry-run", "--skip-packages")
        self.assertEqual(original.read_text(), "unchanged")
        self.assertFalse((self.config / "nvim").is_symlink())
        self.assertEqual(list(self.config.glob("dotfiles-backup.*")), [])

    def test_doctor_is_read_only_and_reports_missing_install(self):
        result = self.run_setup("--doctor", ok=False)
        self.assertIn("MISS nvim config link", result.stdout)
        self.assertFalse(self.config.exists())
        self.assertNotIn("build\n", self.calls())
        self.run_setup("--skip-packages")
        result = self.run_setup("--doctor")
        self.assertIn("Nothing was changed", result.stdout)

    def test_unsupported_machine_fails_before_writes(self):
        self.env["SETUP_TEST_MACHINE"] = "x86_64"
        result = self.run_setup(ok=False)
        self.assertIn("Apple Silicon", result.stderr)
        self.assertFalse(self.config.exists())

    def test_invalid_option_fails_before_writes(self):
        self.run_setup("--wat", ok=False)
        self.run_setup("--doctor", "--start-services", ok=False)
        self.assertFalse(self.config.exists())

    def test_dangerous_checkout_nesting_is_rejected(self):
        nested = self.config / "nvim/dotfiles"
        self.make_checkout(nested)
        result = self.run_setup("--skip-packages", repo=nested, ok=False)
        self.assertIn("Checkout is inside", result.stderr)
        self.assertTrue((nested / "setup.sh").is_file())
        self.assertNotIn("build\n", self.calls())

    def test_root_target_is_rejected(self):
        self.env["DOTFILES_CONFIG_DIR"] = "/"
        result = self.run_setup("--dry-run", ok=False)
        self.assertIn("non-root", result.stderr)

    def test_helper_build_exports_from_checkout_not_live_config(self):
        build = (ROOT / "sketchybar/helpers/build.sh").read_text()
        self.assertIn('CONFIG_DIR="$(dirname "$directory")" "$directory/native_theme" --export-palettes', build)


if __name__ == "__main__":
    unittest.main()
