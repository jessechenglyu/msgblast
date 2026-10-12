// Prepare only an explicitly authorized test worker. Never run on a working desktop.
import AppKit
import CoreGraphics
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

let environment = ProcessInfo.processInfo.environment
guard environment["CI"] == "true" || environment["MSGBLAST_REMOTE_TEST_WORKER"] == "1" else {
    fail("Use the explicit remote UI-test runner; no desktop settings were changed.")
}
let display = CGMainDisplayID()
guard display != 0 else { fail("Native UI tests need a desktop display.") }
let minimumWidth = 1440
let minimumHeight = 900
let bounds = CGDisplayBounds(display)
if bounds.width < CGFloat(minimumWidth) || bounds.height < CGFloat(minimumHeight) {
    let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
    guard let modes = CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode],
          let mode = modes.filter({ $0.width >= minimumWidth && $0.height >= minimumHeight })
            .min(by: { $0.width * $0.height < $1.width * $1.height }) else {
        fail("UI worker needs a display mode of at least 1440 × 900; current display is \(Int(bounds.width)) × \(Int(bounds.height)).")
    }
    let result = CGDisplaySetDisplayMode(display, mode, nil)
    guard result == .success else { fail("Could not prepare the UI display mode (error \(result.rawValue)).") }
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
}
let visible = NSScreen.main?.visibleFrame.size ?? .zero
guard visible.width >= 1000, visible.height >= 780 else {
    fail("UI worker's usable desktop is too small: \(Int(visible.width)) × \(Int(visible.height)).")
}
print("UI desktop geometry: usable \(Int(visible.width)) × \(Int(visible.height)); interactive access still requires a passing UI run.")
