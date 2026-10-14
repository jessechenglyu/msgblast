# Menu bar and shortcut evidence

Source revision: eef21089b1fa0db241e67a84b8b5a0d0532c937a
Base revision: cc0cf40592fdf3c0023c6af9cffe77dfcbc006d5
Captured on Studio, macOS 26.5.2, on October 13, 2026.

The blue msgblast Demo fixture was rebuilt from the committed source, with
production updates disabled. The test installation uses a separate bundle identity
and support profile. All displayed agents, accounts and prompts are simulated;
no messages or paid provider requests were submitted. Permission labels in Demo
are simulated and do not prove live macOS permissions or provider authentication.

The video is a native screen recording, trimmed to its first 95 seconds and played
at 2x speed (47.5 seconds). It shows the grid-agent menu, opening a new ChatGPT
fixture chat, the saved shortcut setting, closing Discover and reopening the
workspace with the global shortcut, and typing into the focused composer.
The purple cursor label comes from the native test driver.

- grid-menu.png: only current grid agents appear in the menu.
- shortcut-settings.png: the optional shortcut is enabled after relaunch.
- new-chat.png: ChatGPT is the only selected recipient; no comparison was created.
- shortcut-result.png: the saved selection and draft remain after reopening.
- menu-bar-shortcut.mp4: the actual native interactions at 2x playback.

XCTest UI assertions could not execute because macOS requested UI Automation
authorization. Native Cua checks used existing authorization on Studio instead.
