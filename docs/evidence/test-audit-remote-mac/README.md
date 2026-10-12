# Test audit and remote Mac workflow evidence

Captured code revision: `cfa552100066f345cecdc7b0126fe4e6a1c83832`.
Base revision: `1d8d4763fbc388cd3c6244057d3c97b00ddf1dd5`.

`remote-runner.png`, `workflow.png`, and `workflow.mp4` render actual recorded
subprocess output from that committed source. `terminal-events.json` retains the
commands, output, elapsed event timestamps, and fixture limits. Playback pauses
were added for readability; the video is a terminal transcript, not a desktop
screen recording or a real remote Mac test run.

The recording shows remote-runner dry-run selection, nine SSH/worker orchestration
tests, 21 preview tests, and 13 download tests passing. SSH is substituted with
local transport fixtures; the worker uses fake native commands. Preview codesign
commands are intercepted against synthetic Mach-O files. The download tests use
local signed feeds and injected fetch/timeout responses. No native Mac tests,
real signing, production requests, or deployments are shown or implied.

The full lightweight baseline also passed: 92 Python tests with one installer
serialization test skipped for missing optional installer libraries, plus 25
Node tests. Native core/controller/updater results belong to the linked GitHub
validation run in the PR; they must not be inferred from these fixture captures.

A live SSH preflight against an available Tailscale Mac stopped because its
Python was older than 3.11. The accessible Macs inspected did not have full Xcode
installed. No native tests ran on the initiating user's desktop. A full successful
personal SSH Mac run requires a dedicated host with the prerequisites documented
in `docs/remote-mac-testing.md`.

The evidence-only commit adds these media and notes; it changes none of the
demonstrated code. PR `Evidence-SHA` identifies the current reviewed branch head.
