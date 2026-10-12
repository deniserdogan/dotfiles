"""Tests encode synthetic fixtures; never change macOS wallpaper or appearance."""
from pathlib import Path
import subprocess
import tempfile
import unittest


class WallpaperTests(unittest.TestCase):
    def test_native_pair_and_global_store_preservation(self):
        with tempfile.TemporaryDirectory(prefix="rice-wallpaper-test-", dir="/private/tmp") as temporary:
            executable = Path(temporary) / "wallpaper_test"
            subprocess.run(["xcrun", "clang", "-O2", "-Wall", "-Wextra", "-fobjc-arc",
                            str(Path(__file__).with_suffix(".m")), "-framework", "AppKit",
                            "-framework", "ImageIO", "-o", str(executable)], check=True)
            subprocess.run([executable, temporary], check=True)


if __name__ == "__main__":
    unittest.main()
