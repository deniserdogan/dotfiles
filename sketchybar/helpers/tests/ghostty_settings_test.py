"""Isolated persistence checks. Never reload or restart the user's terminal."""
from pathlib import Path
import subprocess
import tempfile
import unittest


class GhosttySettingsTests(unittest.TestCase):
    def test_private_settings(self):
        with tempfile.TemporaryDirectory(prefix="rice-ghostty-test-", dir="/private/tmp") as temporary:
            executable = Path(temporary) / "ghostty_settings_test"
            subprocess.run(["xcrun", "clang", "-O2", "-Wall", "-Wextra", "-fobjc-arc",
                            str(Path(__file__).with_suffix(".m")), "-framework", "Foundation",
                            "-o", str(executable)], check=True)
            subprocess.run([executable, temporary], check=True)


if __name__ == "__main__":
    unittest.main()
