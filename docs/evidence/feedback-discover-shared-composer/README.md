# Discover and shared composer feedback evidence

Source revision: `0f80be860468c7bfe158dee6376243f9e43879af`. Base: `1d8d2ac158dfc5aed529d187e334d6d48a7e0786`.

Captured October 12, 2026 in the packaged blue **msgblast Demo**, bundle ID
`com.msgblast.demo`, rebuilt from the clean committed source with Xcode 27.0.
Launch arguments: `--isolated-demo --contacts-access-preview`. Contacts are
simulated as disconnected. The app uses temporary fixture state and local
website pages; no real Messages, Contacts writes, or paid model requests were used.
The installed production app and its state were preserved. Native macOS UI;
mobile screenshots do not apply.

## Workflows

- `instinct-search.png`: typing “instinct” finds the featured Messages setup entry
  while Contacts is disconnected.
- `instinct-setup.png`: Set up opens the existing connection guidance. Closing the
  sheet was verified to leave no deferred error alert.
- `shared-send-results.png`: one bottom-composer prompt and a shared follow-up
  each appear once in both simulated Claude and Grok chats. Both simulated
  responses appear and the shared draft is empty.
- `discover.mp4`: about 10 seconds; four sequential CUA window captures show
  Discover, search, opening setup, and closing it.
- `shared-send.mp4`: about 14 seconds; four sequential CUA window captures show
  the composed prompt, two initial responses, a shared follow-up, and its result.

The MP4s are sampled native workflow captures, not continuous screen recordings.
Idle time is compressed, frames repeat at 20 fps, and screenshots are scaled and
letterboxed to a 1568 × 1080 canvas. The window resized after the first send and
was then resized manually for the follow-up. No UI content was composited or
invented. These clips do not establish animation smoothness or live provider
submission/delivery. Both H.264 videos decoded successfully with ffmpeg.

## Validation

- 120 native tests passed across DiscoverTests, WebServiceTests, and
  MultiWebAgentTests before the final Contacts lookup guard.
- After that guard: build-for-testing, all four focused Discover/current-Grok
  regressions, and the AppModel/web broadcast lifecycle controller fixtures passed.
- The new Grok regression failed on the base source with “page layout is not
  recognized” and passed with the fix. It exercises simultaneous Claude/Grok
  submissions through real page scripts and preserves an independent private draft.
- Read-only inspection of current live Grok markup found zero matches for each
  old editor/account selector and one match each for the replacements. No live
  prompt was submitted. The Demo pages shown here remain local fixtures; current
  Grok combobox/account markup is covered separately by the native regression.
- XCTest's UI runner timed out while enabling automation before running the
  Discover test. Actual CUA performed and verified search, setup, no deferred
  alert, first shared send, and a shared follow-up from the final committed build.
- Independent source review found no actionable defects. Both preview packages
  passed the packager's identity, icon, and ad-hoc signature checks. Dev was not launched.
