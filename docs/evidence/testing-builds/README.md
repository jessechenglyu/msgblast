# Testing publisher local evidence

Source-SHA: 67812679e185b23f7aa3864aa4e63463a593e684

Captured the actual local regression run through a loopback-only report. The browser button invokes the real test_test_builds.py suite from this source. Synthetic bundles and fake GitHub transport; no Apple signing, notarization, or test release was performed.

The 8-second H.264 MP4 uses captured browser frames with edited timing (3 fps playback). It shows the run button, real test output, and the passing result. This local report is evidence scaffolding, not a new product UI.

Full Python tooling suite: 107 tests, 1 skipped. New publisher suite: 9 tests passed. Actionlint 1.7.12 and skill validation passed. Native/hosted publication remains pending after merge and maintainer approval.
