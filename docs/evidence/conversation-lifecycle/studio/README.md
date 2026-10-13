# Studio conversation lifecycle validation

Captured on 2026-10-13 in the persistent `dedicated test guest` Cua Space hosted by dedicated test Mac (macOS 26.5.2), from source `e2feef742c69ecfe85e7eaf8cadc31d7e75b0e5a`, after merging main `79ed7fd`.

The blue Demo uses `com.msgblast.studio-lifecycle-fixture`, a separate support directory and explicit temporary fixture profile. Production updates and telemetry uploads are disabled. The existing Dev app and its profile were preserved. All sends and replies are synthetic; no live provider, Messages delivery, Contacts writes, or TCC retention was tested.

Adding Maple retained window 73 and its exact frame, history and shared draft. Cancel retained the window. Keep Active closed it and reopening preserved an active, editable conversation. End and Close closed it; reopening preserved history and draft while disabling submission. The primary End and Close button is blue.

`workflow.mp4` is an actual native macOS screen recording cropped to the affected window area, exported as H.264 at 24 fps. Waiting periods were removed; retained source intervals (seconds): 0–23, 35–42, 72–80, 97–102, 130–141, 158–164. No generated or reconstructed interaction is included. Original capture was 180 seconds at 60 fps. Cua trajectory video was unavailable; macOS screencapture successfully produced this recording at completion. The abandoned sampled capture was not used.

Validation: merged Demo packaging and signature/icon checks passed. A fresh merged native framework build passed, followed by all 24 web/controller/lifecycle fixture checks. These were run on the build Mac; the actual GUI workflow above was tested on Studio. Native XCTest suites were not rerun on Studio. Ending cutoff rejection of late replies is covered by the controller fixture; this video demonstrates UI behavior and retained same-process history.

Earlier evidence in the parent directory describes its own revision and validation limitations, including the previously disclosed local launch incident. It is historical, not evidence for this merged build.
