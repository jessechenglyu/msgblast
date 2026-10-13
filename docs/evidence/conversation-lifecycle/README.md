# Conversation window and ending evidence

Built source: `8e60315e5a35af23cd00bf44e8dd6abd078eec08`.
Base: `1d8d2ac158dfc5aed529d187e334d6d48a7e0786`.

## Fixture

Actual native app on macOS 27.2, built with Xcode 27.0. The separately packaged
**msgblast Lifecycle Demo** uses the compiled blue AppIconDemo, bundle identifier
`com.msgblast.conversation-lifecycle-fixture`, its own
`msgblast-Lifecycle-Demo-20261012` support folder, simulated Messages and a local
ChatGPT website fixture. Updates are disabled. No messages, Contacts writes,
installed provider CLI requests, deployments or releases were made for these captures.

The window was resized to 1800 × 900 before capture. Adding Maple retained window
5126 at x=1120, y=241, with the same frame, earlier participants, replies and both
drafts. The operating system's window-capture indicator appears in the title bar.

## Native checks

- Adding Maple updated the existing main window and sent only the original shared
  context. Its simulated reply appeared in a new column.
- The native close sheet uses the requested title/body and three actions.
  **End and Close** is the highlighted default action; Escape is Cancel.
- Cancel retained the window, conversation and drafts.
- Keep Active and Close dismissed the window, left the stored cutoff absent,
  and reopened the same interactive workspace with its replies and drafts.
- End and Close persisted a cutoff, four Messages row boundaries and two archived
  web messages before dismissal. Reopening showed preserved history with sends disabled.
- The already-ended window dismissed without another confirmation.
- A normal Quit and actual relaunch retained the exact cutoff, archived web reply,
  conversation identity and drafts. See `validation.json`.

The main SwiftUI workspace is retained while its window is dismissed, so reopening
does not reuse a torn-down hosting graph. Dedicated AppKit panes close normally.

## Verification

The app build passed with isolated derived data at `build/lifecycle`:

```sh
xcodebuild -project msgblast.xcodeproj -scheme msgblast \
  -configuration Debug -derivedDataPath build/lifecycle \
  -destination 'platform=macOS,arch=arm64' \
  MSGBLAST_APP_BUNDLE_IDENTIFIER=com.msgblast.lifecycle-demo \
  ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo CODE_SIGNING_ALLOWED=NO build
bash scripts/test_web_comparisons.sh build/lifecycle
```

The controller scripts passed 21 reported checks, including real AppModel,
WindowCoordinator, LocalStore and WebAgentSession behavior. They verify native
and web membership changes retain NSWindow identity/frame and drafts, switching
workspaces retains the original native transcript, persisted cutoffs reject late
Messages while agent history continues, archived web history stays fixed, ended
follow-ups do not submit, and the real close delegate/reopen paths retain the cutoff.
The lifecycle fixture also verifies safe quit and draft flush behavior.

Native test targets compiled with `build-for-testing`; the new CoreTests case
covers older Codable state and a late linked reply with an earlier message date.
The native XCTest/UI suites were not executed on the active desktop. CI is the
separate native-suite validation path. Pre-existing compiler warnings remain.

Code review completed with no remaining actionable findings. Its external peer
could not start before egress because acpx@0.19.4 was unavailable; the in-process
adversarial fallback ran. Review receipts are retained with this evidence.

## Video

`workflow.mp4` is a 46.2-second H.264 clip sampled from the actual window at about
one frame per second, repeated at 24 fps. It shows adding Maple, the highlighted
close sheet and the close interactions. It is not continuous screen recording.
No audio. Two intervals from the 73-second capture were kept: approximately
0–15 seconds and 35–65 seconds. The intervening pause was removed; timing within
each interval was retained. Window-border padding was normalized to 1600 × 900.
A window-only capture does not show desktop disappearance when dismissed;
separate WindowServer/state checks verified both dismissals. The video decoded
fully with ffmpeg and a frame showing the highlighted button was inspected.

## Limits

All inputs, accounts and replies are synthetic. The checks do not establish live
Messages delivery, live provider authentication or response behavior, macOS 15–25
runtime behavior, or live Messages history retention. Demo reconstructs outgoing
Messages only after restart, so `06-restored.png` demonstrates the persisted web
archive and cutoff rather than reconstructed native replies. The web cutoff
freezes the last observed transcript; unpolled content can be absent.

A preliminary preview launch resolved the compile-only bundle rather than Demo.
It opened and re-saved live app state before being stopped; no messages were sent.
The uniquely identified packaged Demo was then used for all published evidence.
The installed app and the sharing worktree/servers were not replaced or restarted.
