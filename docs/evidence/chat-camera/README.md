# Chat camera evidence

Evidence-SHA: 943942c3c15fe3b79223ca98805f896668f1bb8d
Base-SHA: 1d8d2ac158dfc5aed529d187e334d6d48a7e0786

Captured on macOS 27.2 with the isolated blue msgblast Demo, built with Xcode 27.0.
App identity: com.msgblast.demo.camera-native-final. Production updates are disabled.
The source window, three agent replies and Muse website pane use synthetic local fixtures.
No live provider, Messages send or production account was used.

The camera captures the current chat automatically. Exports preserve the native window
frame, shadow, request title and msgblast label. The operating system's window-sharing
indicator is visible in these captures. The conversation sidebar is excluded from the
export, then restored with the original window frame (1823 × 1100 points for the mixed workspace).

The URL review/result use the actual loopback Worker fixture at backend revision
9013295a4b27aa2895f25bbc512f4d6c0ac2d41a. OAuth and token storage are simulated.
The shared reader returned HTTP 200 with one turn and three replies. The native journal
remained paused with zero private sync lineages and one publication. The service has
not been deployed or configured for production; earlier provider history is excluded.

The H.264 video shows camera activation, the sidebar-free preview, and Copy image.
It consists of 18 window-only samples over about 20 seconds, about one frame per second.
Elapsed timing is preserved; output playback is 24 fps with repeated sampled frames.
No audio or full-desktop recording. It is not a continuous screen recording.

The PNG exports are the app's actual clipboard image. Other PNGs are window-only
captures of the feature and publication workflow. Native UI is macOS-only; no responsive
web UI was changed. macOS 15–25 screenshot fallback was compiled but not run.
