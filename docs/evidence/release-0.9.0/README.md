# 0.9.0 chat images and conversation controls

Base-SHA: cc0cf40592fdf3c0023c6af9cffe77dfcbc006d5
Capture-source-SHA: 157348449a89babdc6bc7f498b960a06ca3f37e2

Captured on October 13, 2026 on the user's Mac: macOS 27.2 (26B5101f), Xcode 27.0 (27A5218g), Cua Driver 0.22.1. The evidence commit added only this directory. App source remains identical to Capture-source-SHA; the later CI follow-up changes only test synchronization and this validation record.

## Public media

All public screenshots, exported image bytes, and video use the packaged blue **msgblast Demo fixture** (`com.msgblast.demo`, `msgblastDemo=true`) launched with `--isolated-demo`. Agents, accounts, prompts, replies, reactions, and permissions are simulated. No real Messages, Contacts writes, paid requests, sign-in, uploads, or actual sharing-service deliveries were used for these captures.

- `01-comparison.png`: two simulated agents and an unsent private draft.
- `02-remove-menu.png`: the actual agent-header removal menu.
- `03-removed.png`: Cedar hidden and excluded from future shared sends, with Lumen still visible.
- `04-image-preview.png`: actual visible-window capture preview with Copy, Save PNG, and native Share. No full-chat URL or recording/account prerequisite.
- `05-exported-image.png`: the exact PNG written by the app through the native Save panel, including window framing. The uniquely named temporary Documents file was moved here after save; existing files were untouched.
- `06-quick-access-menu.png`: tightly cropped screenshot of the actual menu bar menu.
- `07-shortcut-settings.png`: an enabled Control-Shift-Command-B shortcut; simulated permission/account labels remain visible.
- `08-new-blast.png`: menu New Blast returned from Discover to the grid, retained Cedar/Lumen selection, and accepted an unsent draft.

`image-controls.mp4` is a continuous 41.75-second native recording. It shows the removal menu, removal, recipient-pill restoration with the same private draft, camera capture, preview, and Copy image. The clipboard exposed `public.tiff` after Copy. `quick-access.mp4` is a continuous 34.175-second native recording showing Discover, the menu bar menu, New Blast, and typing an unsent draft into the resulting composer. A partial Demo Settings window is also visible in its left edge.

Both recordings were cropped to the actual Demo workflow and re-encoded as H.264 with fast-start metadata and no audio. Playback timing is unchanged: no cuts, speed changes, substituted frames, or reconstructed interactions. Cua's pink cursor is the test driver. Raw full-display recordings, native Save/share-picker inspections, and live-profile captures remain local and are not published. Both MP4s decoded fully with ffmpeg, and representative beginning, interaction, and result frames were inspected. These are native macOS workflows, so mobile screenshots do not apply.

The native share picker opened its `ShareSheet.Popover`; no destination was chosen. UI automation checked image-only preview controls and sidebar restoration. Public recordings do not demonstrate current provider authentication, real delivery, or older macOS capture behavior.

## Validation

On Capture-source-SHA:

- Native core: **354 tests passed, zero failures**, including the final complete rerun after the pane-restoration fix.
- Four affected UI tests passed across focused runs: `testMenuBarNewBlastRetainsSelectionsAndReopensWorkspace`, `testGlobalNewBlastShortcutFromAnotherAppAndDisable`, `testRemoveConversationFromViewPreservesDraftAndCanRestore`, and `testRemoveWebAgentFromViewPreservesConversationAndCanRestore`. The expanded menu case covers image controls, no URL control, sidebar restoration, and removing/reopening an unsent ChatGPT pane through both menu and grid. The shortcut case exercises recording, Escape cancellation, activation from Finder, composer focus, disabling, and no activation after disable. This is not a full UI-suite run.
- Actual AppModel/WindowCoordinator/controller fixtures passed, including no-send quick-chat selection, hidden-agent exclusion, saved drafts and comparison membership, lifecycle, and failed-flush handling. All sends inside those fixtures use local simulated transports.
- Python tooling: **97 tests run, with one optional installer-dependency skip**.
- Dev and Demo packaging, strict ad-hoc signature checks, compiled blue-green/blue icon checks, distinct bundle/support identities, and disabled production updates passed. Project regeneration produced no further diff.
- Full source review completed under run `20261014-combined-090`: one P2 pane-reopening finding was repaired. The external review transport failed before code egress; an independent local adversarial review ran instead. No source or live data reached Grok.

Commands used:

```sh
xcodebuild -project msgblast.xcodeproj -scheme msgblast -configuration Debug \
  -derivedDataPath build/release-090-tests -destination 'platform=macOS,arch=arm64' \
  MSGBLAST_APP_BUNDLE_IDENTIFIER=com.msgblast.release090-tests \
  ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo -only-testing:msgblastTests test
bash scripts/test_web_comparisons.sh build/release-090-tests
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/tests -p 'test_*.py'
python3 scripts/build_preview_apps.py --sha 157348449a89babdc6bc7f498b960a06ca3f37e2 \
  --run-url 'Local 0.9.0 validation on this Mac; no Actions run' \
  --output build/release-090-final-preview
```

UI cases used the same xcodebuild settings with their individual `-only-testing:msgblastUITests/...` selectors. Their source was unchanged when the final source commit was made. Initial imported shortcut/menu tests failed on stale CheckBox/MenuBarItem queries and String-only numeric-value casts; those selectors/assertions were corrected and the affected cases rerun successfully. One intermediate UI runner attempt timed out while enabling automation mode before executing any case; later focused execution succeeded without changing permissions. The pre-fix pane defect was reproduced manually in the live Dev profile, then the corrected grid path passed live and both entry points passed the native UI regression.

## Separate live-profile check and limits

The final blue-green **msgblast Dev** (`com.msgblast.development`, `msgblastDemo=false`, `msgblast-Dev` support folder) was built from Capture-source-SHA and opened on this Mac without Demo arguments. Its existing state and saved unsent drafts loaded. A real Grok website surface rendered in its existing profile; removing an unsent pane and explicitly reopening it restored the pane after the fix. Its camera preview included the composited website and excluded the sidebar. Menu New Blast retained the live selection. The temporary Grok selection was restored to its initial unselected state, and the owned Dev preview was quit normally.

This ad-hoc Dev build lacked Full Disk Access, so current Messages history could not be read. Grok was signed out; no authenticated provider turn, current delivery, Contacts write, permission reset, or paid request was attempted. Live captures stay local. Production and the installed Dev app bundle were not overwritten. The user’s live Messages database remained read-only/unmodified.

The macOS 15–25 capture fallback compiled but was not runtime-tested on an older OS. Capture-error restoration is covered by source review of the defer path, not an injected ScreenCaptureKit failure. The occupied-shortcut path was reviewed but not exercised with a deliberately conflicting chord. These remain validation limits rather than claimed passes.

No app publication, release tag, production build-counter allocation, deployment, or updater feed change occurred. This PR prepares reviewed source and release notes for **0.9.0**; distribution remains a separate maintainer action.

## CI follow-up

The first Actions run on `afa27312b2800c358f42313dc33f0d1d68ffda74` failed the existing `testIdleEvictionReopensSavedHistoryWithoutResending`. A single failed-job rerun passed that case but failed the neighboring `testEvictionInspectsFreshDraftsAndKeepsRepliesStillArriving` at its final reply snapshot assertion. Both failures are retained in [run 38510389736](https://github.com/mgalpert/msgblast/actions/runs/38510389736).

Both tests previously used background polling while assuming an immediate explicit eviction/refresh would run. `WebAgentSession` conservatively skips a page already being refreshed. The follow-up uses the existing `connect(automaticallyRefresh: false)` fixture mode and bounded, awaited refreshes to observe the required replies. It retains real WebKit pages and the checks for page eviction/recreation, no repeated submission, fresh draft retention, and a pending reply surviving eviction. No production code or visual behavior changes; the captured app still matches the reviewed app source.

Local verification: both affected cases passed ten iterations each (20 tests, zero failures) using the same Xcode settings above with their focused `-only-testing` selectors and `-test-iterations 10`. Independent review found no issues. These cases now isolate eviction behavior from the periodic poller; they do not prove poller interaction. Other existing session tests continue to use automatic polling.
