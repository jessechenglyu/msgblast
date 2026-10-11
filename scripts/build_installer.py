#!/usr/bin/env python3
"""Package an already-built app as a drag-to-Applications DMG; does not publish."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def run(*args):
    subprocess.run(args, check=True, timeout=60)


def installer_layout(style):
    if style == "remotion":
        return {"bounds": "{{120, 120}, {960, 600}}", "app": (290, 340),
                "applications": (670, 340), "icon_size": 96.0}
    if style == "classic":
        return {"bounds": "{{120, 120}, {660, 400}}", "app": (180, 210),
                "applications": (480, 210), "icon_size": 96.0}
    raise ValueError(f"Unknown installer style: {style}")


def write_layout(mount, app_name, style="classic"):
    layout = installer_layout(style)
    from ds_store import DSStore
    from mac_alias import Alias
    alias = Alias.for_file(str((mount / ".background/install.png").resolve()))
    if alias.target.posix_path not in (b"/.background/install.png", "/.background/install.png"):
        raise RuntimeError("Installer background alias must stay inside its volume")
    background = alias.to_bytes()
    with DSStore.open(str(mount / ".DS_Store"), "w+") as store:
        store["."]["bwsp"] = {
            "ShowStatusBar": False, "ShowToolbar": False, "ShowTabView": False,
            "ContainerShowSidebar": False, "ShowSidebar": False,
            "WindowBounds": layout["bounds"]
        }
        store["."]["icvp"] = {
            "viewOptionsVersion": 1, "backgroundType": 2,
            "backgroundColorRed": 1.0, "backgroundColorGreen": 1.0, "backgroundColorBlue": 1.0,
            "gridOffsetX": 0.0, "gridOffsetY": 0.0,
            "backgroundImageAlias": background, "iconSize": layout["icon_size"],
            "textSize": 14.0, "gridSpacing": 100.0, "arrangeBy": "none",
            "labelOnBottom": True, "showItemInfo": False, "showIconPreview": True
        }
        store["."]["icvl"] = ("type", "icnv")
        store[app_name]["Iloc"] = layout["app"]
        store["Applications"]["Iloc"] = layout["applications"]
    # Read the serialized metadata back before packaging; missing layout is fatal.
    with DSStore.open(str(mount / ".DS_Store"), "r") as store:
        if (store[app_name]["Iloc"] != layout["app"]
                or store["Applications"]["Iloc"] != layout["applications"]
                or store["."]["bwsp"]["WindowBounds"] != layout["bounds"]
                or store["."]["icvp"]["backgroundImageAlias"] != background):
            raise RuntimeError("Installer Finder layout did not serialize correctly")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--style", choices=("classic", "remotion"), default="classic",
                        help="Finder background/layout; remotion is static, never plays video")
    args = parser.parse_args()
    app, output = args.app.resolve(), args.output.resolve()
    if app.suffix != ".app" or not (app / "Contents/Info.plist").is_file():
        parser.error("app must be a built .app bundle")
    if output.exists():
        parser.error("output already exists; choose a new filename")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="msgblast-installer-") as temporary:
        root = Path(temporary).resolve()
        source = root / "source"
        source.mkdir()
        run("ditto", str(app), str(source / app.name))
        (source / "Applications").symlink_to("/Applications", target_is_directory=True)
        (source / ".background").mkdir()
        if args.style == "remotion":
            shutil.copyfile(Path(__file__).with_name("installer-assets") / "remotion-background.png",
                            source / ".background/install.png")
        else:
            run("swift", "-module-cache-path", str(root / "module-cache"),
                str(Path(__file__).with_name("installer_background.swift")),
                str(source / ".background/install.png"))
        writable = root / "installer.dmg"
        run("hdiutil", "create", "-srcfolder", str(source), "-volname", f"Install {app.stem}",
            "-format", "UDRW", str(writable))
        mount = root / "mounted"
        mount.mkdir()
        run("hdiutil", "attach", "-nobrowse", "-mountpoint", str(mount), str(writable))
        try:
            write_layout(mount, app.name, args.style)
        finally:
            run("hdiutil", "detach", str(mount))
        run("hdiutil", "convert", str(writable), "-format", "UDZO", "-o", str(output))
        run("hdiutil", "verify", str(output))
    print(output)


if __name__ == "__main__":
    main()
