# Local performance milestone — Demo evidence

Source/Evidence-SHA: `b224679f9dd224b8642a8bbab5541229eca4b760`
Base-SHA: `1d8d4763fbc388cd3c6244057d3c97b00ddf1dd5`

These files show the actual native app built from the frozen feature head. This
separate evidence-only branch retains media without advancing that source head.
Keep the evidence branch/commit available while reviewers use these URLs.

## Configuration and limits

The preview packager built blue msgblast Demo with `com.msgblast.demo`, fixture
mode, empty update feed, and disabled production updates. After packaging, only
the support-folder metadata was overridden to `msgblast-PerfEvidence-b224679`,
and the bundle was ad-hoc re-signed. The executable feature code is unchanged.
`manifest.json` records that configuration and executable SHA-256. This dedicated
synthetic profile enabled relaunch checks without touching production, Dev, or
the normal Demo support folders. Their running apps were not restarted.

Cedar Messages, ChatGPT's embedded page, and Codex CLI use app-owned synthetic
fixtures. Inputs/accounts/replies are simulated, and timings measure simulated
response delays. No real Messages, Contacts, provider CLI, paid model request,
live login, cloud sync, publication, contribution, merge, release or deployment
was performed. The app's development version is not a published release claim.

Recordings capture one native window, include no audio, and are resized for
playback without time edits. The comparison video shows submission and observed
replies; the window grows during native layout, so its rightmost edge is clipped
in part of that recording. Full-pane screenshots complement it. The Settings
video shows Benchmarks, My Stats, opening the local favorite and returning.
XCTest UI automation timed out before execution; these are actual computer-use
checks, not an XCTest UI pass or proof of today's authenticated provider layouts.

## Demonstrated workflow

1. New profile starts with tracking off, no recorded activity or historical guesses.
2. Enable local tracking and choose website/CLI/Messages fixture agents.
3. Submit a shared prompt; inspect native observed timing and explicit CLI final
   output timing. Favorite → thumbs down → clear → favorite remains reversible.
4. Send a private CLI turn, then repeat the shared prompt. The local journal has
   separate authoritative initial/private/shared request groups, with shared
   positions `[1,2,1]` aligned by action ID and exact targets rather than text.
5. My Stats shows one recorded comparison/seven attempted agent turns, separate
   initial/follow-up samples, observed reply/outcome fractions, and unavailable
   Messages completion. Raw configured UUIDs are absent from the primary rows.
6. Benchmarks shows local-only/account-not-connected content. Favorite navigation
   opens saved shared/private replies locally without contacting a provider.
7. Disable recording. Counts/favorite persist and ordinary idle closure is not
   partial. Relaunch retains tracking off, counts and favorite; per-reply feedback
   controls remain hidden while off.

Native core validation on this source: 345 tests, zero failures. Eleven focused
performance tests and actual four-connector/controller/configured-CLI fixtures
passed. Exact multiline paragraph/preformatted-code text persisted through the
actual WebKit recorder and disk reload; hidden DOM payloads stayed absent. The
controller fixture covers scoped/global gaps, interrupted recording and recovery,
nil-replyTo/source-owned follow-up association, and grouped repeated/subset actions.
These fixture checks do not prove live accounts or production TCC behavior.

## Files

- `my-stats-off.png`: default-off/empty tracking state.
- `comparison-timing.png`: compact website, final CLI and Messages timing/feedback.
- `comparison-follow-up.png`: additional shared request after a private CLI turn.
- `my-stats-recorded.png`: samples/rates and unavailable Messages completion.
- `benchmarks-local-only.png`: distinct honest cloud extension boundary.
- `favorite-local.png`: local saved comparison, with active controls.
- `my-stats-disabled-retained.png`: disabled tracking retains records.
- `my-stats-relaunch.png` and `favorite-relaunch.png`: retention and hidden controls.
- `comparison-feedback.mp4`: comparison submission/observed timing interaction.
- `stats-tabs-and-favorites.mp4`: Settings and saved favorite interaction.
