import SwiftUI
import WebKit
import UniformTypeIdentifiers
import msgblastCore

/// Captures only the bound app window. WebKit draws out of process, so its
/// visible viewport is composited separately over the native window image.
@MainActor enum ChatWindowCapture {
    static func capture(_ window: NSWindow) async throws -> NSImage {
        guard let view = window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CaptureError.unavailable
        }
        view.layoutSubtreeIfNeeded()
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(bitmap)
        func webViews(_ node: NSView) -> [WKWebView] {
            if let web = node as? WKWebView { return [web] }
            return node.subviews.flatMap(webViews)
        }
        for web in webViews(view) where !web.isHiddenOrHasHiddenAncestor && !web.visibleRect.isEmpty {
            let configuration = WKSnapshotConfiguration()
            configuration.rect = web.visibleRect
            let snapshot = try await web.takeSnapshot(configuration: configuration)
            // AppKit's image context has an upward Y axis; the hosting view may
            // be flipped. Clip to the current viewport, never the whole page.
            var rect = view.convert(web.visibleRect, from: web)
            if view.isFlipped { rect.origin.y = view.bounds.height - rect.maxY }
            image.lockFocus()
            snapshot.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
            image.unlockFocus()
        }
        return image
    }
    enum CaptureError: LocalizedError {
        case unavailable
        var errorDescription: String? { "The chat window could not be captured. Try again when it is visible." }
    }
}

private struct ChatWindowAnchor: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ChatShareButton: View {
    @ObservedObject var model: AppModel
    var comparisonID: UUID?
    @State private var anchor = NSView()
    @State private var image: NSImage?
    @State private var capturing = false
    @State private var error: String?
    @State private var showingPreview = false
    var body: some View {
        Button {
            guard let window = anchor.window else { error = ChatWindowCapture.CaptureError.unavailable.localizedDescription; return }
            capturing = true
            Task { @MainActor in
                defer { capturing = false }
                do { image = try await ChatWindowCapture.capture(window); showingPreview = true }
                catch { self.error = error.localizedDescription }
            }
        } label: { Label("Capture chat", systemImage: "camera").labelStyle(.iconOnly) }
        .accessibilityLabel("Capture chat")
        .help("Preview and share an image of this chat window")
        .disabled(capturing)
        .background(ChatWindowAnchor(view: anchor).frame(width: 0, height: 0))
        .sheet(isPresented: $showingPreview, onDismiss: { image = nil }) {
            if let image { ChatSharePreview(model: model, comparisonID: comparisonID, image: image) }
        }
        .alert("Capture chat", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}

private struct ChatSharePreview: View {
    @ObservedObject var model: AppModel
    let comparisonID: UUID?
    let image: NSImage
    @Environment(\.dismiss) private var dismiss
        @State private var error: String?
    @State private var copied = false
    private var hasRecording: Bool {
        guard let comparisonID else { return false }
        return model.performance.events.contains { $0.comparisonID == comparisonID.uuidString }
    }
    var body: some View {
        let recorded = hasRecording
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Share chat").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Visible chat window").font(.headline)
            Text("Review the image before sharing. It includes visible drafts and private conversations.")
                .font(.callout).foregroundStyle(.secondary)
            Image(nsImage: image).resizable().scaledToFit()
                .accessibilityLabel("Captured chat window preview")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            HStack {
                Button(copied ? "Copied image" : "Copy image") {
                    NSPasteboard.general.clearContents()
                    copied = NSPasteboard.general.writeObjects([image])
                }
                Button("Save image…") { save() }
                ImageSharePicker(image: image)
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("More than fits on screen?").font(.headline)
                    Text("Review the recorded conversation and create a scrollable link.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if let comparisonID {
                    ComparisonShareButton(model: model, comparisonID: comparisonID, title: "Share full chat by URL…")
                }
            }
            if !recorded {
                Text("URL sharing needs a recorded comparison. Enable recording in My Stats before starting a chat. Image sharing works without recording or an account.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .padding(24).frame(minWidth: 600, idealWidth: 800, minHeight: 540, idealHeight: 700)

    }
    private func save() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "msgblast-chat.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) else { throw ChatWindowCapture.CaptureError.unavailable }
                try png.write(to: url, options: .atomic)
            } catch { self.error = error.localizedDescription }
        }
    }
}

private struct ImageSharePicker: NSViewRepresentable {
    let image: NSImage
    func makeCoordinator() -> Coordinator { Coordinator(image: image) }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "Share image…", target: context.coordinator, action: #selector(Coordinator.share(_:)))
        button.bezelStyle = .rounded
        return button
    }
    func updateNSView(_ nsView: NSButton, context: Context) {}
    @MainActor final class Coordinator: NSObject {
        let image: NSImage
        init(image: NSImage) { self.image = image }
        @objc func share(_ sender: NSButton) {
            NSSharingServicePicker(items: [image]).show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
