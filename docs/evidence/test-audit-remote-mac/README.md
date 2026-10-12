# Test audit and remote Mac workflow evidence

Captured code revision: `4e6f77083af8b0b46ba0e5e0b4744d93ca62b817`.
Base revision: `1d8d4763fbc388cd3c6244057d3c97b00ddf1dd5`.

`remote-runner.png`, `workflow.png`, and `workflow.mp4` render actual recorded
subprocess output from that committed source. `terminal-events.json` retains the
commands, output, elapsed event timestamps, and fixture limits. Playback pauses
were added for readability; the video is a terminal transcript, not a desktop
screen recording or a real remote Mac test run.

The recording shows remote-runner dry-run selection with explicit Xcode/Python,
twelve SSH/worker orchestration
tests, 21 preview tests, and 13 download tests passing. SSH is substituted with
local transport fixtures; the worker uses fake native commands. Preview codesign
commands are intercepted against synthetic Mach-O files. The download tests use
local signed feeds and injected fetch/timeout responses. No native Mac tests,
real signing, production requests, or deployments are shown or implied.

The full lightweight baseline also passed: 95 Python tests with one installer
serialization test skipped for missing optional installer libraries, plus 25
Node tests. Native core/controller/updater results belong to the linked GitHub
validation run in the PR; they must not be inferred from these fixture captures.

A first live SSH preflight stopped because Apple's Python was older than 3.11.
The user then authorized the other MacBook: its Homebrew Python 3.14 is ready,
and a subsequent Xcode cache transfer was stopped at the user’s request. The
user is handling the macOS/Xcode update. A full personal SSH native run is not
shown in these fixture captures. No native tests
ran on the initiating user's desktop. See `docs/remote-mac-testing.md` for the
dedicated host prerequisites and result format.

The first GitHub run on `8440e7fcaacad044d59e936032ac545bdfb07128` passed 344
native core tests, updater fixtures, and simulated permission checks. Its
controller step failed because `rg` was absent. The captured revision repairs
source discovery with Python; its regression failed before that fix and passes
after it. The PR records fresh GitHub/native results separately.

The evidence-only commit adds these media and notes; it changes none of the
demonstrated code. PR `Evidence-SHA` identifies the current reviewed branch head.
