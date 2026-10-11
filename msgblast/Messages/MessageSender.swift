import Foundation
import msgblastCore

@MainActor
struct MessageSender {
    // No participant creation and no group APIs: the exact existing chat is the only target.
    func send(_ text: String, to chat: Chat) async throws {
        try await submit(MessagesSendScript.text(text, to: chat))
    }
    func send(_ attachment: MessageAttachment, to chat: Chat) async throws {
        guard FileManager.default.isReadableFile(atPath: attachment.url.path) else { throw SendFailure.notSubmitted("The attachment is unavailable. Restore the saved file before retrying.") }
        guard chat.eligible else { throw SendFailure.notSubmitted("This Messages destination is unsupported. Refresh its conversation before sending.") }
        // Messages' sandboxed transfer processes cannot read arbitrary app-data
        // paths. Hand off a private copy in its attachment namespace; the saved
        // draft remains in msgblast. Retain the copy for asynchronous processing.
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Messages/Attachments/msgblast-Outgoing", isDirectory: true)
        let file: URL
        do { file = try MessagesAttachmentStaging.stage(attachment, in: root) }
        catch { throw SendFailure.notSubmitted("Could not prepare the attachment for Messages: \(error.localizedDescription)") }
        try await submit(MessagesSendScript.attachment(path: file.path, to: chat))
    }
    private func submit(_ source: String) async throws {
        // NSAppleScript must run on a process's main thread. Isolate it from the UI process.
        let result = try await Task.detached(priority: .userInitiated) { try Self.execute(source) }.value
        if result == "SUBMITTED" { return }
        if result.hasPrefix("NOT_SUBMITTED:-1743\n") {
            throw SendFailure.notSubmitted("Automation permission denied. Allow msgblast to control Messages in System Settings → Privacy & Security → Automation. Your message is saved for retry.")
        }
        if result.hasPrefix("NOT_SUBMITTED:") {
            let detail = result.split(separator: "\n", maxSplits: 1).last.map(String.init) ?? result
            throw SendFailure.notSubmitted("\(detail) Nothing was sent. Refresh the conversation before retrying.")
        }
        // Timeouts and other execution failures may follow an accepted send. Never resend automatically.
        throw SendFailure.ambiguous(result.replacingOccurrences(of: "iMessage", with: "Messages"))
    }

    nonisolated private static func execute(_ source: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]
        let input = Pipe(), output = Pipe(), errors = Pipe()
        process.standardInput = input; process.standardOutput = output; process.standardError = errors
        let completed = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completed.signal() }
        do { try process.run() } catch { throw SendFailure.notSubmitted("Could not start the Messages submission: \(error.localizedDescription)") }
        do {
            try input.fileHandleForWriting.write(contentsOf: Data(source.utf8))
            try input.fileHandleForWriting.close()
        } catch {
            process.terminate()
            throw SendFailure.ambiguous("The submission process stopped unexpectedly. Refresh to reconcile before sending again.")
        }
        if completed.wait(timeout: .now() + 35) == .timedOut {
            if process.isRunning { process.terminate() }
            if completed.wait(timeout: .now() + 2) == .timedOut, process.isRunning { kill(process.processIdentifier, SIGKILL) }
            throw SendFailure.ambiguous("Messages did not respond in time. The submission may have been accepted. Refresh to reconcile; do not resend.")
        }
        let stdout = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else { throw SendFailure.ambiguous(stderr.isEmpty ? "Messages submission stopped unexpectedly. Refresh to reconcile." : stderr.replacingOccurrences(of: "iMessage", with: "Messages")) }
        return stdout
    }
}
