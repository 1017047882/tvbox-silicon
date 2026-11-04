"""Regression checks for deployment floors and non-destructive FFmpeg setup."""

import pathlib
import os
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class DeploymentTests(unittest.TestCase):
    def test_app_and_package_target_ios15(self):
        self.assertRegex((ROOT / "project.yml").read_text(), r"iOS: '15\.0'")
        self.assertIn(".iOS(.v15)", (ROOT / "Package.swift").read_text())

    def test_native_ios_targets_do_not_require_ios17(self):
        for name in ["ffmpeg", "interpreter", "jvm", "libffi", "native-bindings"]:
            with self.subTest(script=name):
                text = (ROOT / f"Scripts/build-apple-{name}.sh").read_text()
                self.assertNotRegex(text, r"(?:apple-ios|miphoneos-version-min=|mios-simulator-version-min=)17\.0")
                self.assertRegex(text, r"(?:apple-ios|miphoneos-version-min=)15\.0")
                self.assertRegex(text, r"(?:tvos17\.0|mtvos-version-min=17\.0)")

    def test_python_wheels_keep_tvos17(self):
        text = (ROOT / "Scripts/build-apple-python-wheels.sh").read_text()
        self.assertIn("IPHONEOS_DEPLOYMENT_TARGET=15.0 TVOS_DEPLOYMENT_TARGET=17.0", text)

    def test_ffmpeg_has_no_recursive_deletion(self):
        text = (ROOT / "Scripts/build-apple-ffmpeg.sh").read_text()
        self.assertNotRegex(text, r"\brm\s+-[A-Za-z]*r")

    def test_ffmpeg_preserves_unexpected_output(self):
        git_bash = pathlib.Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe"
        bash = str(git_bash) if os.name == "nt" and git_bash.exists() else shutil.which("bash")
        if not bash:
            self.skipTest("Bash is required to exercise the real shell link function")
        text = (ROOT / "Scripts/build-apple-ffmpeg.sh").read_text()
        function = re.search(r"^link\(\) \{.*?^\}", text, re.M | re.S).group()
        self.assertNotRegex(function, r"\brm\s+-[A-Za-z]*r", "Unsafe function must not be executed")
        # No recursive cleanup: keep temporary output under the ignored build directory.
        build = ROOT / "build"
        build.mkdir(exist_ok=True)
        folder = pathlib.Path(tempfile.mkdtemp(prefix="ffmpeg-link-test-", dir=build))
        link = folder / "FFmpeg.xcframework"
        link.mkdir()
        sentinel = link / "keep.txt"
        sentinel.write_text("preserve this output")
        command = f'set -eu\nLINK="{link.as_posix()}"\nOUTPUT="{folder.as_posix()}/cache"\n{function}\nlink\n'
        result = subprocess.run([bash, "-c", command], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(sentinel.read_text(), "preserve this output")
        self.assertIn("Refusing", result.stderr)


if __name__ == "__main__":
    unittest.main()
