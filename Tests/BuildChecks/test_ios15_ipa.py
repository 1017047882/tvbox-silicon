"""Reject binaries that cannot load on an iOS 15 device before IPA publication."""
import importlib.util
import pathlib
import struct
import unittest
import plistlib
import tempfile
import os
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("ipa_check", ROOT / "Scripts/check-ios15-app.py")
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


def binary(cpu=0x0100000C, platform=2, minimum=(15, 0, 0)):
    version = minimum[0] << 16 | minimum[1] << 8 | minimum[2]
    return struct.pack("<8I", 0xFEEDFACF, cpu, 0, 2, 1, 24, 0, 0) + struct.pack("<6I", 0x32, 24, platform, version, 0, 0)


class IPABinaryTests(unittest.TestCase):
    def test_arm64_in_fat_container_is_accepted(self):
        image = binary()
        header = struct.pack(">2I", 0xCAFEBABE, 1)
        entry = struct.pack(">5I", 0x0100000C, 0, 28, len(image), 0)
        self.assertEqual(CHECK.check_macho(header + entry + image, (15, 0, 0)), (15, 0, 0))

    def test_fat_container_rejects_other_architecture(self):
        image = binary(cpu=0x01000007)
        data = struct.pack(">7I", 0xCAFEBABE, 1, 0x01000007, 0, 28, len(image), 0) + image
        with self.assertRaisesRegex(ValueError, "arm64"):
            CHECK.check_macho(data, (15, 0, 0))

    def test_fat_container_rejects_out_of_bounds_slice(self):
        data = struct.pack(">7I", 0xCAFEBABE, 1, 0x0100000C, 0, 4096, 56, 0)
        with self.assertRaises(ValueError):
            CHECK.check_macho(data, (15, 0, 0))

    def test_fat_arm64_still_rejects_newer_os(self):
        image = binary(minimum=(16, 0, 0))
        data = struct.pack(">7I", 0xCAFEBABE, 1, 0x0100000C, 0, 28, len(image), 0) + image
        with self.assertRaisesRegex(ValueError, "minimum"):
            CHECK.check_macho(data, (15, 0, 0))

    def test_device_ios15_is_accepted(self):
        self.assertEqual(CHECK.check_macho(binary(), (15, 0, 0)), (15, 0, 0))

    def test_newer_minimum_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "minimum"):
            CHECK.check_macho(binary(minimum=(16, 0, 0)), (15, 0, 0))

    def test_simulator_is_rejected_even_when_arm64(self):
        with self.assertRaisesRegex(ValueError, "platform"):
            CHECK.check_macho(binary(platform=7), (15, 0, 0))

    def test_wrong_architecture_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "arm64"):
            CHECK.check_macho(binary(cpu=0x01000007), (15, 0, 0))

    def test_truncated_command_is_rejected(self):
        with self.assertRaises(ValueError):
            CHECK.check_macho(binary()[:-4], (15, 0, 0))

    def test_missing_deployment_command_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "deployment"):
            CHECK.check_macho(struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, 0, 0, 0, 0), (15, 0, 0))

    def test_legacy_ios_deployment_command_is_accepted(self):
        data = struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 6, 1, 16, 0, 0)
        data += struct.pack("<4I", 0x25, 16, 13 << 16, 0)
        self.assertEqual(CHECK.check_macho(data, (15, 0, 0)), (13, 0, 0))

    def test_complete_bundle_requires_all_runtimes(self):
        build = ROOT / "build"
        build.mkdir(exist_ok=True)
        app = pathlib.Path(tempfile.mkdtemp(prefix="ipa-check-test-", dir=build))
        (app / "Info.plist").write_bytes(plistlib.dumps({
            "MinimumOSVersion": "15.0", "UIDeviceFamily": [1], "CFBundleExecutable": "TVBox-iOS"}))
        (app / "TVBox-iOS").write_bytes(binary())
        with self.assertRaisesRegex(ValueError, "missing runtime"):
            CHECK.check_app(app)
        for relative in ["lib/lib/modules", "JavaHost/host.jar", "JavaHost/apple-bindings.jar",
                         "PythonHost/host.py", "python/lib/python3.14/README", "NodeHost/main.mjs"]:
            path = app / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture")
        for relative in ["Frameworks/Python.framework/Python", "Frameworks/NodeMobile.framework/NodeMobile"]:
            path = app / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(binary())
        self.assertEqual(len(CHECK.check_app(app)["images"]), 3)
        (app / "Frameworks/Python.framework/Python").write_bytes(binary(minimum=(16, 0, 0)))
        with self.assertRaisesRegex(ValueError, "Python.framework"):
            CHECK.check_app(app)

    def test_generated_project_contains_only_iphone_target(self):
        spec = importlib.util.spec_from_file_location("iphone_project", ROOT / "Scripts/make-iphone-project.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        project = {"options": {}, "targets": {"TVBox-iOS": {"settings": {}}, "TVBox-tvOS": {}, "TVBox-macOS": {}},
                   "packages": {name: {} for name in ["TVCore", "Perception", "NavigationBackport", "Sparkle", "ColorfulX"]}}
        result = module.iphone_project(project)
        self.assertEqual(list(result["targets"]), ["TVBox-iOS"])
        self.assertEqual(result["targets"]["TVBox-iOS"]["settings"]["TARGETED_DEVICE_FAMILY"], "1")
        self.assertEqual(result["targets"]["TVBox-iOS"]["settings"]["SUPPORTED_PLATFORMS"], "iphoneos")
        self.assertEqual(set(result["packages"]), {"TVCore", "Perception", "NavigationBackport"})
        self.assertIs(result["targets"]["TVBox-iOS"]["info"]["properties"]["TVBoxCloudSyncAvailable"], False)

    def test_stale_outputs_are_preserved_and_outside_paths_rejected(self):
        git_bash = pathlib.Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git/bin/bash.exe"
        bash = str(git_bash) if os.name == "nt" and git_bash.exists() else shutil.which("bash")
        if not bash:
            self.skipTest("Bash is required")
        build = ROOT / "build"
        build.mkdir(exist_ok=True)
        folder = pathlib.Path(tempfile.mkdtemp(prefix="ipa-preserve-test-", dir=build))
        sentinel = folder / "keep.txt"
        sentinel.write_text("preserve this output")
        command = f'set -eu\nsource Scripts/preserve-build-path.sh\npreserve_build_path "build/{folder.name}"\n'
        result = subprocess.run([bash, "-c", command], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(folder.exists())
        matches = list((build / "preserved").glob(f"output.*/{folder.name}/keep.txt"))
        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0].read_text(), "preserve this output")
        result = subprocess.run([bash, "-c", 'source Scripts/preserve-build-path.sh; preserve_build_path project.yml'],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((ROOT / "project.yml").is_file())
