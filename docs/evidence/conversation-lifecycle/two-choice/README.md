# Two-choice conversation closing

Source: `9fe98c81ba1bce7abaa9c3a26f3da1109e821c02`. Captured 2026-10-13 in `dedicated test guest`, the isolated macOS 26.5.2 Space hosted by the dedicated test Mac.

The dialog has only End and Close and Keep Active and Close. End and Close remains the blue default (Return). Escape is assigned to Keep Active and Close. No Cancel button remains. The GUI check verified both buttons close the window, reopening after Keep Active preserves an editable conversation and draft, and reopening after End preserves history/draft with sending disabled.

The rebuilt packaged blue Demo uses `com.msgblast.studio-two-choice-fixture` and an explicit temporary fixture profile. Its updates and telemetry uploads are disabled. All conversations and replies are simulated; no real sends, providers, Contacts writes or permissions changes. The existing Studio Dev app and profile were preserved.

Packaging, native compilation, compiled blue icon and strict signature validation passed. The controller fixture suite passed for the preceding merged source; this UI-only change was verified through the actual updated Studio GUI rather than adding implementation-mirroring tests. Native XCTest suites were not rerun.

Video is an actual native macOS screen recording cropped to the Demo window area, exported as H.264 at 24 fps. The idle tail is removed; no generated or reconstructed interaction is included. Earlier captures under `studio/` and in the parent folder describe their own revisions and are historical, including the earlier three-choice dialog.
