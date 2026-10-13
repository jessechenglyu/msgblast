# 0.7.2 functional Dev preflight

Reviewed source and intended release tag: `8b4b99111d1b61332614a046f08978a613fb74a5`.
Native computer use through cua_repl on October 12, 2026, macOS 27.2.

The preview packager rebuilt the clean committed source. Blue-green msgblast Dev:
`com.msgblast.development`, `msgblastDemo=false`, `msgblastSupportDirectory=msgblast-Dev`,
empty production feed and key. Strict ad-hoc signatures, hardened runtime, Address Book
and Automation entitlements verified. Production green artwork remained unchanged.
No demo/isolated-demo launch arguments were passed to Dev.

Verified with actual keyboard/click interactions:

- Cmd+2 and Cmd+F navigate to Discover and focus search. “instinct” finds its setup entry.
- Opening setup displays access guidance. Closing it returns without an error alert.
- A synthetic, unsent shared draft survives Cmd+W then Cmd+N to close/reopen the main
  window. The original selected Grok recipient survives too.
- The synthetic draft and Discover query were cleared afterward, with the original
  recipient selection retained. No comparison was created or request submitted.

Messages history access was unavailable and Grok was signed out in this Dev profile.
No system permission was changed or reset, sign-in performed, Contacts written,
real message sent, or paid request made. This verifies functional Dev navigation and
local draft/recipient behavior. The separately labeled Demo/native DOM regressions
verify simulated broadcast receipt behavior, not live provider submission/delivery
or installed-production update/permission retention.

Screenshots contain only the filtered featured entry, setup guidance, or a crop of
the synthetic composer. The two composer crops exclude the real saved-agent grid;
uncropped grid captures remain local and are not published.

`dev-preflight.mp4` is about 12 seconds: four sequential native CUA captures, compressed
timing, repeated frames at 20 fps, scaled/letterboxed to 1568 × 1080. It is a sampled
workflow video, not a continuous recording or animation-smoothness claim. The last
capture shows the retained draft after reopening. No UI content was invented.
