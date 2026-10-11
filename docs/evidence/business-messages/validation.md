# Business conversation routing validation

This implementation is fixture-verified infrastructure, not proof that the user's Poke conversation is Apple Messages for Business or that Messages can send to it through AppleScript.

## Behavior

Contacts addresses remain discovery hints. The conversation chooser records one exact chat GUID, address, service, and Business capability classification. A saved identity must still match after refresh; disappearance or changed metadata never falls back to another number. Multiple matching contact addresses require an explicit choice. Legacy contacts with one matching address still choose their newest ordinary iMessage thread.

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

Read-only context: `/Users/contains/.codex/worktrees/b6d0/msgblast`, branch `codex/onboarding-checklist`. No edits or commits were made there. Its current flow is connector selection → Messages checklist → `OnboardingDiscoveredMessagesView` (`Agents we found`). This implementation is based on its committed base `61ab391536b500856a854b9bddd59d0d063a4d06`; uncommitted redesign changes were not absorbed.

The calling chat must integrate these helpers into that discovery list after incorporating the implementation:

- Resolve the saved agent via `model.savedAgent(matching: agent)` when rendering the Contacts snapshot. `model.route`, `model.conversation`, and `model.messageConnectionStatus` already do that internally when the incoming snapshot has no explicit destination.
- Replace `No conversation yet · saved for later` with `model.messageConnectionStatus(agent)`. A chosen Business destination needs to say `Business conversation found · sending unavailable`.
- Replace `Uses your most recent conversation` with the actual `model.conversation(agent)?.displayName` or GUID/handle. Multiple matching contact numbers now require a choice; they are not activity-ranked alternatives.
- Render `MessagesConversationMenu(model: model, agent: saved)` outside the Select/Deselect button. It saves exactly one identity and deselects the previous send recipient.
- Recompute completion from `model.route(saved) != nil` after a choice; save the Business identity while keeping it incomplete/unavailable for shared sending.
- In `restoreRecipients`, filter discovered/saved IDs through `model.route` before making them recipients. Being discovered or checked is not evidence of send readiness.

Current-flow UI acceptance should launch the isolated Business fixture, choose `Connect Messages`, continue through the simulated permissions checklist, find the Poke row with two fixture numbers on `Agents we found`, choose the opaque Business conversation, verify the saved capability label, continue with another supported agent, and verify Poke is never a send recipient. Test this against the integrated redesign, not the committed old chooser.
