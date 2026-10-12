# Shared conversation reader evidence

Evidence-SHA: 8f9ec5b76887e71a1cca19f84bfa91cf20466170
Base-SHA: 1d8d2ac158dfc5aed529d187e334d6d48a7e0786
Foundation-SHA: 9013295a4b27aa2895f25bbc512f4d6c0ac2d41a

All captures show the actual final reader from a local Miniflare Worker with
D1, R2 and Static Assets. Identity and conversations are synthetic fixtures.
No production deployment, real provider requests or native sends.

The dark app screenshots use the earlier native Demo sample, renamed synthetic
labels, and four explicitly simulated follow-ups to exercise long conversations.
The light screenshots/video use the browser regression fixture with three agents,
a targeted missing reply, hostile text rendered inert, and long follow-up messages.

Desktop columns scroll vertically independently. At740px, a horizontal wheel
gesture over a transcript scrolls the agent columns. At390px, tabs switch agents.
The video is a continuous scripted Playwright browser recording, converted from
WebM to H.264 without changing timing. It shows desktop horizontal/vertical
scrolling and the existing revoked-link result; no audio. Screenshots include
both light and dark appearance and a phone viewport.

Validation:40 Worker tests, TypeScript and non-deploying bundle checks passed.
Final-source browser checks passed desktop/mobile overflow, horizontal gestures
over bubbles, full transcript scrolling, agent switching, script escaping, scoped
private prompts and revoked-link handling. Benchmark fields remain in the approved
JSON but are hidden from the chat reader.
