# Business conversation routing validation

The matching-stage limitations below are historical. See [Business sending verification](sending.md) for the implemented send path and current live-test limits.

This implementation is fixture-verified infrastructure, not proof that the user's Poke conversation is Apple Messages for Business or that Messages can send to it through AppleScript.

## Behavior

Contacts addresses remain discovery hints. The conversation chooser records one exact chat GUID, address, service, and Business capability classification. A saved identity must still match after refresh; disappearance or changed metadata never falls back to another number. Unbound regular contacts automatically use the most recent supported conversation across their saved addresses. Poke automatically matches an exact Poke title with positive Business metadata, provided the matching threads share one Business identity. The exact destination is then persisted; different Business identities remain unresolved rather than being guessed.

The reader retains chat service/display metadata and positively flags the Apple Business extension payload identifier. Business conversations are inspectable/selectable but never send-ready. Opaque non-phone/non-email addresses are also unavailable for sending, even when the database says iMessage. The existing sender remains exact-chat AppleScript and rejects unsupported destinations before running the script or staging an attachment. No Business send was attempted.

## Metadata evidence and limits

The Apple Business extension identifier is independently documented in the upstream imessage-exporter implementation (`imessage-database/src/tables/messages/message.rs`, Business extension classification) and its Business variant fixture:
https://github.com/ReagentX/imessage-exporter/blob/0d444ab3220f5940d4632c05da4628009c785a02/imessage-database/src/tables/messages/message.rs
https://github.com/ReagentX/imessage-exporter/blob/0d444ab3220f5940d4632c05da4628009c785a02/imessage-database/src/tables/messages/tests/variant.rs

The installed Messages scripting dictionary exposes sending to a chat, participants, and iMessage/SMS/RCS account types. It does not establish Business compatibility. An extension marker is positive payload evidence, not a universal Business chat schema: a text-only Business conversation may lack it. No business UUID is inferred from a phone number or display name, and no contact-name match auto-connects a thread.

Direct read-only inspection of the user's `~/Library/Messages/chat.db` failed with `authorization denied` on 2026-10-11. The running Dev app's granted access does not authorize this process. Actual Poke GUID, service, handles, chat metadata and AppleScript visibility remain unverified. The live diagnosis remains blocked pending metadata read through an authorized process. No permissions were reset, Contacts changed, real messages sent, paid requests made, or production app replaced.

## Fixtures

`--demo --isolated-demo --onboarding-preview --business-messages-preview` creates a synthetic Poke contact with two fixture numbers and a separate opaque Business destination. The fixture supplies the destination and capability state for a chooser interaction. The current uncommitted onboarding redesign is not included in this checkout. This is not captured customer data.

Core tests cover exact destination Codable round trips, stale/changed identities, duplicate identity ambiguity, multiple-number ambiguity, legacy decoding, ordinary iMessage newest-thread selection, read-only SQLite Business metadata, opaque identifiers, and Business send exclusion.

## Screenshots

No accepted screenshot evidence is available yet. An attempted test targeted the committed, obsolete onboarding flow; its new test and onboarding edits were removed after the user corrected the flow. The current onboarding worktree was read for context only. Old-flow screenshots must not be used as evidence for the redesigned discovery list. Native UI testing was also canceled at authentication; no permission change or retry is authorized by that cancellation.

## Video

A playable interaction recording is not yet available. Local Xcode UI test evidence is not PR-hosted evidence. The caller must capture the changed fixture interaction and provide repository-accessible screenshots/video before creating or updating a PR, per AGENTS.md.

## Integration with the current onboarding redesign

Integrated on `codex/poke-onboarding-integration`, based on onboarding PR #52.
The discovery list saves an automatic destination, displays the matched Business
name and capability state, and offers no conversation chooser. Already-saved
contacts without a destination are matched too. Unsupported Business destinations
remain visible but are excluded from send recipients and from the actionable
setup reminder. Business sends remain blocked until the adapter is verified.

The synthetic fixture uses an exact `Poke` Business title and positive Business
classification with an opaque destination, separate from its two contact numbers.
Routing tests cover automatic matching, persistence, removal without phone fallback,
wrong/unverified names, ambiguous Business identities, and multiple regular numbers.
Live Poke metadata and sending still require verification through the app.

## Integrated validation (2026-10-11)

80 focused native routing/database/onboarding/grid tests passed. The final Dev
and Demo previews built and passed packaging signature/icon checks. Native Demo
inspection verified automatic Poke Business matching without a chooser, a saved
Business capability label, a visible workspace tile excluded from send recipients,
and no actionable setup reminder for that unsupported capability.

The rebuilt live Dev app reported missing Full Disk Access. The older build's
granted access did not remain usable after this ad-hoc rebuild, so the user's
actual Poke metadata and Business sending remain unverified. No real message was
sent. The matching integration is complete; the send-ready user experience is not.
