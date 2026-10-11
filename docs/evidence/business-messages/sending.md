# Business send implementation and verification

The Business send path is implemented on the automatic-matching integration based on `d85d6e4`. No merge, production release, live send, Contacts write, permission reset, or replacement of the currently tested integration app was performed.

## Destination and readiness

A Business destination is sendable only when it has positive Business metadata, exactly one participant, iMessage service, a `urn:biz:` handle containing a UUID, and a GUID equal to either `any;-;HANDLE` or `iMessage;-;HANDLE`. Arbitrary opaque identifiers, unverified Business handles, mismatched GUIDs, SMS and groups remain unavailable.

Refresh also pins previously saved Poke contacts that have no destination once a unique sendable Business conversation is found. That pin is persisted once and never moved to another GUID or contact number. The saved database identity remains unchanged. Only its exact, validated Business alias is used by Messages scripting: `any;-;urn:biz:UUID`. The existing chat is looked up directly. No phone recipient, new participant, group or fallback conversation is created. Automatic Poke matching, ambiguity protection and ordinary Messages routing remain intact.

Preflight and sending share the same script generator. Before the single send command, it checks the scripting ID, iMessage account, one participant, and exact participant handle. Text and staged attachments use that same target. Errors before submission return `NOT_SUBMITTED`; errors after entering the send command remain uncertain, preserving the existing no-blind-resend behavior and subprocess timeout protections.

Onboarding labels valid Business destinations `Connected · Business conversation`; they can become selected recipients. Invalid or unsupported Business destinations retain the unavailable label. The current discovered-agent row exposes capability as an accessibility value. The Business Demo fixture uses a synthetic UUID and two synthetic contact numbers.

## Actual Poke inspection

Read-only inspection through the installed Messages scripting interface found the existing Poke chat with an `any;-;urn:biz:…` ID, one participant, iMessage account and the identical Business URN participant. Looking up the `iMessage;-;…` form failed with -1728. This verifies why the Business alias must be used; it does not prove remote delivery.

The production-generated read-only preflight, which contains no send command, returned `READY` for actual Poke. A second read-only preflight with an intentionally mismatched participant returned `NOT_SUBMITTED:-2700` and `The destination participant changed.` No message body/history was read by those scripts and neither script can send.

Direct database access from the agent process remains denied by macOS. The running Onboarding Ready Dev app's automatic Business match was confirmed through Computer Use. Its state and app bundle were left untouched. The raw live inspection/preflight artifacts are kept locally under `build/business-evidence`; they are not committed or uploaded.

## Tests

The new Business eligibility regression first failed in four assertions against the integrated blanket exclusion. After implementation, 88 focused native tests passed across `CoreTests`, `MessagesDatabaseTests`, `MessagesSendScriptTests`, `OnboardingTests` and `AgentGridTests`.

The script tests cover the exact Business alias, unchanged ordinary GUID targeting, participant/service/ID guards, groups/SMS/unverified identities, no-send preflight, compile-only checks of text/attachment scripts with quotes/backslashes/newlines, and pre-/post-submission error separation. Script compilation does not execute a send.

The current-flow Business onboarding UI test was updated to expect a connected, automatically selected recipient. Its flow was verified manually through cua-driver in a separately signed, isolated Demo app. The native UI test itself was not run in this pass.

Native command:

```sh
xcodebuild -project msgblast.xcodeproj -scheme msgblast \
  -configuration Debug -derivedDataPath build/business-sending-tests \
  -destination 'platform=macOS,arch=arm64' \
  MSGBLAST_APP_BUNDLE_IDENTIFIER=com.msgblast.business-sending-tests \
  ASSETCATALOG_COMPILER_APPICON_NAME=AppIconDemo CODE_SIGN_IDENTITY=- \
  -only-testing:msgblastTests/CoreTests \
  -only-testing:msgblastTests/MessagesDatabaseTests \
  -only-testing:msgblastTests/MessagesSendScriptTests \
  -only-testing:msgblastTests/OnboardingTests \
  -only-testing:msgblastTests/AgentGridTests test
```

## Screenshots

Local Computer Use captures show the current connector/checklist/discovery flow, Poke's connected Business label, selected workspace tile, Poke as the sole recipient, and the simulated comparison result. These are development QA artifacts under `build/business-evidence`, not PR-hosted evidence. The Demo app explicitly labels its workflow `Local fixture · no real sends` and comparison title `[Demo]`. The fixture response is synthetic and must never be described as a real Poke reply.

Before creating/updating a PR, capture and host final-revision screenshots within the repository's access boundary. No unrelated window capture substitutes for this feature.

## Video

No playable video was captured in this implementation pass and no PR was created. The caller must capture and host the changed workflow's video before creating/updating a PR. Local screenshots or a screenshot slideshow are not a substitute for that interaction recording.

## Prepared live test — approval required

Recipient: **Poke's existing Apple Messages for Business conversation**, identified by the exact Business URN inspected above. Do not send to either Contacts phone number or to another selected agent.

Proposed text: **msgblast Business routing check. Please reply with “received”.**

No test has been sent. The user must explicitly approve this recipient and exact content before execution. Then use the fixed build, inspect Poke as the sole selected recipient, send once, and verify the outgoing history receipt and response in that same Business conversation. Do not automatically resend after a timeout or uncertain result.

Live text submission/delivery, real Poke response, and Business attachment delivery are not yet verified. Existing state is preserved; no production release is authorized.
