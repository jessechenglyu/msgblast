# Named agents and multiple bots

Implementation source: `3763928cfe179aa7a3da79cb50283dfda925190c`.
Base: `2cc4e312bf036a82abd0ccb168ed8a030382fdb2`.

Captured from a rebuilt, signed blue Demo app with a dedicated bundle identity
and support folder. Production and shared Dev/Demo profiles were preserved.
Saved fixtures from the initial QA run were reopened by the committed build;
new comparisons and the targeted bot follow-up were performed in that build.

The screenshots show Duplicate with shared/separate sign-in choices, independently
selected copies, distinct ChatGPT conversation URLs, named bot entries, two bot
replies, a private follow-up to Research Bot, and restored comparison membership.
Use New Blast explicitly when starting a fresh comparison after reopening the app.

`walkthrough.mp4` is a **stepped recording with edited timing**, assembled from
actual native window captures after the relevant interactions. It is not a
continuous pointer recording. Original PNGs are unedited. The video captions
identify each operation and keep the fixture limitation visible.

All website replies and bot callbacks are simulated. No live routine, tunnel,
real Messages/Contacts write, website account sign-in, or paid model request was
used for visual evidence. Provider model/reasoning controls remain manual;
agent names are labels. Native macOS UI has no mobile target.

Validation: 307 native unit tests passed (zero failures/skips), including actual
hardware-encrypted restoration of three distinct synthetic bot credentials.
A blocked-profile regression proves another profile can progress while further
operations on the blocked profile remain rejected. The actual AppModel/LocalStore
controller fixtures passed two-instance conversation, private scope, restored
selection, draft and shutdown checks. Duplicate/Rename UI test passed on rerun;
its first attempt encountered concurrent foreground UI test activity.

The independent code review completed with eight local lenses. Both retained
findings were fixed and verified. The requested external Grok route could not
start before egress; no cross-model corroboration is claimed.

See `validation.json` for source and screenshot hashes, app identity and limits.
