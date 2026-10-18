# msgblast for Windows (preview)

A native Windows (WPF, .NET 8) version of msgblast: ask once, compare the answers side by side.
It lives beside the macOS app and does not change it.

## What it does today

- **Blast one message to several agents at once** and show each reply in its own pane.
- **Follow-ups keep each agent's own conversation.** Each agent resumes its own CLI session.
- **Local CLI agents:** Codex CLI (`codex`) and Claude Code (`claude`), found on `PATH` (npm `.cmd` shims included). The arguments and output parsing match the macOS app's optional CLI conversations in `msgblast/Core/LocalPersonalAgent.swift`. Prompts go through stdin, and the installed CLI's own configuration and permission rules apply. Nothing prompts interactively, and child processes run with no console window and are killed as a tree on timeout or cancel.
- **Demo mode (`--demo`):** three simulated fixture agents with labeled, deterministic replies that never contact any service. Demo mode uses a separate profile.
- **Saved comparisons** in `%APPDATA%\msgblast-Windows` (Demo: `%APPDATA%\msgblast-Windows-Demo`). Writes are atomic. An unreadable state file is left untouched and the app becomes read-only instead of replacing it.
- **A failed send is shown as failed** and is never retried automatically.

## Not supported yet (compared with the macOS app)

| macOS feature | Windows status |
| --- | --- |
| Messages / iMessage agents and Messages reports | **Not possible.** They depend on macOS Messages, `chat.db` and Apple Events. Windows has no equivalent. |
| Web accounts (ChatGPT, Claude, Grok, Gemini, Meta AI…) in embedded browser windows | Not yet. The natural next step is WebView2 with per-provider page scripts ported from `msgblast/Core/WebPageScript.swift`. |
| Comparison reports by a personal agent (fail-closed no-tool mode) | Not yet. |
| Cursor, Gemini CLI, Pi, Grok, Hermes CLIs | Not yet. Only Codex CLI and Claude Code are wired up. |
| Attachments, Discover, Grok bot, Sparkle updates, telemetry, feedback | Not included. |
| Signed installer | Not included. CI publishes an unsigned self-contained build as an artifact. |

## Build and test

Requires the .NET 8 SDK on Windows 10/11.

```powershell
cd windows
dotnet build msgblast-windows.sln -c Release
dotnet test msgblast-windows.sln -c Release --no-build
# Headless end-to-end check of the real window with the Demo fixture (no window is shown):
src\Msgblast.Windows\bin\Release\net8.0-windows\msgblast.exe --smoke-test $env:TEMP\msgblast-smoke
```

The smoke test renders the real `MainWindow` offscreen and blasts two messages to the three Demo agents. It writes `frame-*.png` and `smoke-result.json`, and exits 0 only when all six replies were delivered and persisted with session ids.

Run the app with `msgblast.exe` (installed CLIs) or `msgblast.exe --demo`. Add `--data-dir <path>` to use an isolated profile.

Publish a single self-contained exe:

```powershell
dotnet publish src\Msgblast.Windows -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o ..\build\windows\msgblast-win-x64
```

## Layout

- `src/Msgblast.Core`: platform-neutral models, store, CLI adapters, detection, backends, and the blast controller (`net8.0`)
- `src/Msgblast.Windows`: WPF app and the headless smoke test (`net8.0-windows`)
- `tests/Msgblast.Core.Tests`: xUnit tests
- CI: `.github/workflows/windows.yml` on `windows-2022`
