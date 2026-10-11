# Opt-in Remotion Finder layout

`remotion-background.png` is the 960 × 600 static export of the selected Remotion onboarding final frame. It deliberately contains no app/folder icons or their labels: Finder supplies the actual draggable app and `/Applications` alias at (290, 340) and (670, 340), with 96-point icons.

Source and asset inventory: `../../prototypes/remotion-onboarding/`. From that folder, run `npm ci`, then `bash update-installer-background.sh` (requires ffmpeg) to regenerate. The animation remains a separate H.264 preview. Finder never plays it.

Use the existing installer tool explicitly:

```sh
python3 scripts/build_installer.py 'PATH/msgblast Demo.app' OUTPUT.dmg --style remotion
```

Install `scripts/installer-requirements.txt` in a virtual environment first. The classic style remains the default and release automation is unchanged. The existing publisher already distributes a DMG alongside the updater ZIP; `latest.zip` still serves the ZIP. This work neither selects the new appearance for releases nor publishes it.

For a local fixture, package the isolated blue Demo app, not the installed production app. The Demo icon/name differ from the canonical green app artwork in the animation by design. The DMG volume uses the supplied app's name. A Demo drag would copy `msgblast Demo.app` independently; do not replace the live app merely to test this layout.

The animation can play in Remotion Studio or any MP4 player, and can later be embedded in an existing web download/onboarding page. No such page or native playback surface is added here; no executable installer is introduced.
