import Foundation

/// One exact existing destination. Preflight and submission share the same checks.
/// The read-only source never contains a send command and is safe to inspect a live target.
public enum MessagesSendScript {
    public static func preflight(to chat: Chat) throws -> String { try source(to: chat, expression: nil) }
    public static func text(_ text: String, to chat: Chat) throws -> String { try source(to: chat, expression: literal(text)) }
    public static func attachment(path: String, to chat: Chat) throws -> String {
        try source(to: chat, expression: "(POSIX file \(literal(path)))")
    }
    private static func source(to chat: Chat, expression: String?) throws -> String {
        guard let targetID = chat.messagesScriptingID else {
            throw SendFailure.notSubmitted("This Messages destination is unsupported. Refresh its conversation before sending.")
        }
        let command = expression.map { "set submissionAttempted to true\n                    send \($0) to targetChat\n                    return \"SUBMITTED\"" } ?? "return \"READY\""
        return """
        set submissionAttempted to false
        try
            with timeout of 20 seconds
                tell application "Messages"
                    set targetChat to chat id \(literal(targetID))
                    if (id of targetChat as text) is not \(literal(targetID)) then error "The destination identity changed."
                    if (count of participants of targetChat) is not 1 then error "The destination is no longer one-to-one."
                    if service type of account of targetChat is not iMessage then error "The destination does not support this conversation."
                    if (handle of item 1 of participants of targetChat as text) is not \(literal(chat.handle)) then error "The destination participant changed."
                    \(command)
                end tell
            end timeout
        on error detail number code
            if submissionAttempted then return "UNCERTAIN:" & code & linefeed & detail
            return "NOT_SUBMITTED:" & code & linefeed & detail
        end try
        """
    }
    private static func literal(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n") + "\""
    }
}
