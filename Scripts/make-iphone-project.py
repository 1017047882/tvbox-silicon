#!/usr/bin/env python3
"""@brief Generate an iPhone-only XcodeGen spec without changing other app targets."""
import pathlib


def iphone_project(project):
    project["name"] = "TVBox-iPhone"
    project["targets"] = {"TVBox-iOS": project["targets"]["TVBox-iOS"]}
    project["packages"] = {name: package for name, package in project["packages"].items()
                           if name in {"TVCore", "Perception", "NavigationBackport"}}
    project["options"]["deploymentTarget"] = {"iOS": "15.0"}
    target = project["targets"]["TVBox-iOS"]
    # Unsigned side-load archives have no iCloud KVS entitlement.
    target.setdefault("info", {}).setdefault("properties", {})["TVBoxCloudSyncAvailable"] = False
    target["settings"].update({"TARGETED_DEVICE_FAMILY": "1", "SUPPORTED_PLATFORMS": "iphoneos",
                                "SUPPORTS_MACCATALYST": "NO", "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO"})
    for phase in target.get("postBuildScripts", []):
        phase["script"] = phase["script"].replace("rsync -a --delete ", "rsync -a ")
    return project


if __name__ == "__main__":
    import yaml

    root = pathlib.Path(__file__).resolve().parents[1]
    source = yaml.safe_load((root / "project.yml").read_text(encoding="utf-8"))
    (root / ".ios15-project.generated.yml").write_text(
        yaml.safe_dump(iphone_project(source), sort_keys=False), encoding="utf-8")
