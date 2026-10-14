import AppKit
import Carbon
import SwiftUI

/// Registers one explicit system-wide shortcut; no global keyboard monitoring or TCC grant.
@MainActor
final class NewBlastShortcut: ObservableObject {
    struct Shortcut: Codable, Equatable {
        var keyCode: UInt32
        var modifiers: UInt32
        var label: String
    }
    @Published private(set) var shortcut: Shortcut?
    @Published private(set) var enabled = false
    @Published private(set) var recording = false
    @Published private(set) var error: String?
    var onTrigger: (() -> Void)?
    private let defaults: UserDefaults
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var monitor: Any?
    nonisolated private static let signature: OSType = 0x6d736762 // msgb

    private static let shortcutKey = "newBlastShortcut"
    private static let enabledKey = "newBlastShortcutEnabled"

    init() {
        // UI fixtures never retain a shortcut or claim the user's saved chord.
        defaults = ProcessInfo.processInfo.arguments.contains("--isolated-demo")
            ? UserDefaults(suiteName: "com.msgblast.shortcut-fixture.\(UUID().uuidString)")! : .standard
        if let data = defaults.data(forKey: Self.shortcutKey) { shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) }
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.signature == NewBlastShortcut.signature, id.id == 1 else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<NewBlastShortcut>.fromOpaque(context).takeUnretainedValue().onTrigger?()
            }
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        if status != noErr { error = "macOS could not enable the shortcut. Relaunch msgblast to try again." }
        if defaults.bool(forKey: Self.enabledKey), let shortcut { enabled = register(shortcut) }
    }
    isolated deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }
    private func register(_ value: Shortcut) -> Bool {
        guard handler != nil else { return false }
        let status = RegisterEventHotKey(value.keyCode, value.modifiers,
                                        EventHotKeyID(signature: Self.signature, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        guard status == noErr else {
            error = "That shortcut is unavailable or already in use. Choose another combination."
            return false
        }
        error = nil
        return true
    }
    func setEnabled(_ value: Bool) {
        cancelRecording()
        error = nil
        if value, let shortcut { enabled = register(shortcut) }
        else { unregister(); enabled = false }
        defaults.set(enabled, forKey: Self.enabledKey)
    }
    func beginRecording() {
        cancelRecording()
        unregister()
        recording = true; error = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self else { return false }
                if event.keyCode == 53 { self.cancelRecording(); return true }
                let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
                guard !flags.intersection([.command, .option, .control]).isEmpty,
                      let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
                    self.error = "Include Command, Option, or Control with a key."
                    return true
                }
                var modifiers: UInt32 = 0
                var label = ""
                for (flag, carbon, symbol) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] where flags.contains(flag) {
                    modifiers |= UInt32(carbon); label += symbol
                }
                label += characters.uppercased()
                let candidate = Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, label: label)
                if self.register(candidate) {
                    self.shortcut = candidate; self.enabled = true
                    self.defaults.set(try? JSONEncoder().encode(candidate), forKey: Self.shortcutKey)
                    self.defaults.set(true, forKey: Self.enabledKey)
                    self.finishRecording()
                }
                return true
            }
            return consumed ? nil : event
        }
    }
    private func finishRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; recording = false
    }
    func cancelRecording() {
        guard recording else { return }
        finishRecording()
        if enabled, let shortcut { enabled = register(shortcut) }
    }
}

struct NewBlastShortcutSettings: View {
    @ObservedObject var shortcut: NewBlastShortcut
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start a New Blast from the menu bar or a system-wide shortcut using your selected agents.")
                .foregroundStyle(.secondary)
            HStack {
                Toggle("Enable global New Blast shortcut", isOn: Binding(get: { shortcut.enabled }, set: { shortcut.setEnabled($0) }))
                    .toggleStyle(.switch).accessibilityLabel("Enable global New Blast shortcut")
                    .disabled(shortcut.shortcut == nil || shortcut.recording)
                Text(shortcut.shortcut?.label ?? "Not set").monospaced().accessibilityLabel("New Blast shortcut")
                Button(shortcut.recording ? "Cancel Recording" : "Record Shortcut") {
                    if shortcut.recording { shortcut.cancelRecording() } else { shortcut.beginRecording() }
                }
            }
            if shortcut.recording { Text("Press your shortcut. Escape cancels.").foregroundStyle(.secondary) }
            if let error = shortcut.error { Text(error).foregroundStyle(.red) }
            Text("Available while msgblast is running. Opens the composer without sending a message.").font(.caption).foregroundStyle(.secondary)
        }
        .onDisappear { shortcut.cancelRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in shortcut.cancelRecording() }
    }
}
