# Chrome profile names

Source revision: `b075b6c48080945cf282932b0b3b69ed0849fe9b`.
Base revision: `2cc4e312bf036a82abd0ccb168ed8a030382fdb2`.

Native macOS Demo evidence uses fictional profiles **Alex (Personal)** and
**Jordan (Work)**. Demo injects these labels and simulated sign-ins; it does not
read real Chrome profiles or cookies. The importer tests separately exercise
the actual Local State reader with temporary Chrome directories and metadata.

The video presents captured native window states in interaction order, with
edited timing and repeated frames. It is not a continuous screen recording.
No labels or controls have been retouched. Mobile evidence does not apply to
this native macOS picker.

Six BrowserLoginImporterTests passed, including Unicode custom names, account
names, duplicate display names retaining distinct store identities, malformed
metadata, blank names, missing Local State, and existing cookie import tests.
The first UI run selected the renamed profile and connected ChatGPT, but failed
waiting for the subsequent Claude connection page (line 36); an unchanged rerun
passed the complete UI test. No live browser
account or macOS permission flow was exercised.

Thanks to [@shreyans___](https://x.com/shreyans___) for the feedback that Chrome's
folder names made it hard to choose the right profile.
