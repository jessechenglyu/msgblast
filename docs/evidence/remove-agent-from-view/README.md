# Agent pane removal evidence

Application source: `095ecc96acfab94ddb10f028e74f608066f680a4`.
Base: `cc0cf40592fdf3c0023c6af9cffe77dfcbc006d5`.

Captured from the committed native app in Xcode 27 on macOS using
`--demo --isolated-demo` and the blue Demo artwork. The UI runner uses bundle
ID `com.msgblast.remove-agent-tests`. This is an isolated Demo test fixture,
with synthetic Messages and local website accounts/replies. It makes no real
Messages sends or provider requests and does not establish live authentication
or delivery. The separately packaged Dev and Demo previews use the same source.

Screenshots show the comparison before removal, the agent-header menu, the
comparison after Muse is hidden, and a joined Messages comparison after Lumen
is hidden. The web workflow recording shows the right-click menu, removal,
recipient exclusion, and restoration with the original reply intact. The video
is a 6.7-second excerpt at normal speed, cropped to the app window and resized
for playback; setup and test teardown are omitted. No interactions are simulated
in the recording beyond the accurately labeled Demo data and responses.

Validation: 354 native unit tests passed. Both focused removal UI checks passed,
and passed again from the committed source. The Messages check confirms Lumen's
private draft survives removal/restoration. The web check confirms another pane
remains visible and the original reply survives restoration. Separate-window
and inactive-history paths were checked by source review. The initial UI attempt
failed in an older fixture setup, and another run timed out during keyboard event
synthesis before reaching removal; final focused checks passed. One preliminary
capture run was canceled while configuring video retention.

Dev and Demo packaging verified the separate identities/support profiles,
disabled production updates, compiled icon colors, and ad-hoc signatures.
No production app was installed, replaced, or released.
