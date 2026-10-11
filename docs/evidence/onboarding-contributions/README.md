# Onboarding contribution choices

Captured October 10, 2026 from application source
`e5a1d9f624ff4e5aa6cf9652ebcb1fe2014bf2f8`, based on upstream
`2cc4e312bf036a82abd0ccb168ed8a030382fdb2`.

- `onboarding.jpg`: the final setup step shows feedback and feature building side by side.
- `feature-prompt.jpg`: the existing contribution prompt opened from the new onboarding action.
- `workflow.mp4`: sampled native-window captures of opening the prompt, copying it, returning to onboarding, and finishing setup. Encoded at 2 fps with edited timing to hold each state; this is not a continuous full-desktop recording.

The app was built with `scripts/build_preview_apps.py` from the committed source.
Evidence uses the blue **msgblast Demo** (`com.msgblast.demo`). Its local bundle
was given `msgblastOnboardingPreview=true` and `msgblastIsolatedDemo=true`, then
ad-hoc re-signed and verified. These are fixture launch flags; application source
was unchanged. The displayed version/build are local development defaults, not
production release values. The captured executable path was verified against
this worktree's `build/onboarding-pr-preview/msgblast Demo.app`.

Accounts and conversations are simulated. No real Messages, Contacts writes,
provider requests, feedback submission, or production updates were exercised.
Manual native interaction confirmed the split screen, prompt opening, copy
confirmation, return to onboarding, and completion into the workspace.

Validation: Xcode 27 native core suite passed all 299 tests. Both packaged Dev
and Demo builds passed ad-hoc signature and compiled-icon validation. The
focused XCTest UI run was interrupted by foreground windows; it is not claimed
as passing. Native computer-use verification above covers the changed flow.
