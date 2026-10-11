# Remotion onboarding evidence

Base-SHA: `2cc4e312bf036a82abd0ccb168ed8a030382fdb2`
Implementation/build revision: `e3276a1e43fea4530e45195861cfacda6e8432e9`

This directory records the selected eight-second onboarding animation with the supplied soundtrack, the final static layout, and the real mounted blue Demo fixture installer. Evidence-only commits after the implementation revision do not change the rendered source or packaged workflow.

- `onboarding.mp4`: H.264/AAC, 1920 × 1200, 30 fps, eight seconds; actual Remotion render with the supplied track at original speed/pitch/gain. The final subheading is “your next agent message starts here”. This is a standalone media asset, not a recording of Finder animating.
- `overload.png`: opening of the real render, showing uniformly spaced rows of the 102 repository agent artwork assets.
- `final-frame.png`: final animation frame with the canonical green app icon and installation cue.
- `finder-mounted.png`: actual mounted Demo DMG window, captured with cua-driver. Blue `msgblast Demo.app` and the Applications alias are real Finder items; their artwork and labels are not baked into the background.

Local validation: 83 Python tooling tests (including serialized Finder metadata), TypeScript source check, Remotion render/still/background commands, isolated Dev/Demo native preview builds and signature/compiled-icon checks, DMG checksum verification, mounted app identity/state/update checks, Applications alias resolution, and visual inspection of frame samples and the mounted Finder window. The committed installer background matches the rendered static scene at 960 × 600.

Fixture limits: the Demo bundle uses `com.msgblast.demo`, explicit fixture mode, `msgblast-Demo` support state and disabled updates. Ad-hoc signed local previews are not notarized. No app copy into Applications, live sends, paid requests, production releases or deployments were performed. The native core/unit suite awaits CI. Native UI tests were not run because native app behavior is unchanged. Direct listening is unavailable in the authoring session; audio timing was checked using waveform/signal alignment and encoded stream timing.

Standard Finder DMG backgrounds are static. `--style remotion` opts into this final background and the real draggable layout; the existing classic default and release automation are unchanged. The MP4 can play in Remotion Studio or a media player, or later be embedded in an existing download/onboarding page. No custom executable installer is included.

To reproduce, use `prototypes/remotion-onboarding/README.md` for the animation and `scripts/installer-assets/README.md` for packaging. The app builds used the implementation revision named above; the final PR head adds only these evidence files.
