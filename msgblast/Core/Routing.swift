import Foundation
public enum ChatResolver {
    public static func normalize(_ value: String) -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.contains("@") { return value }
        guard value.allSatisfy({ $0.isNumber || "+()- .".contains($0) }) else { return value }
        return value.filter { $0.isNumber || $0 == "+" }
    }
    // A chosen conversation never falls back to a contact number or a newer thread.
    public static func conversation(agent: Agent, chats: [Chat]) -> Chat? {
        if let destination = agent.destination {
            let matches = chats.filter { destination.matches($0) }
            return matches.count == 1 ? matches[0] : nil
        }
        if let business = automaticBusinessConversation(agent: agent, chats: chats) { return business }
        return resolve(handles: agent.handles, chats: chats)
    }
    public static func automaticBusinessConversation(agent: Agent, chats: [Chat]) -> Chat? {
        func brand(_ name: String) -> String {
            name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .components(separatedBy: .alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
        }
        guard ["poke", "poke ai", "poke agent"].contains(brand(agent.name)) else { return nil }
        let matches = chats.filter {
            $0.businessConversation == true && brand($0.displayName ?? "") == "poke"
        }
        // Match only positively identified Business metadata and an exact brand.
        // Different Business identities are ambiguous; never guess from phone numbers.
        guard !matches.isEmpty, matches.count == 1 || (matches.allSatisfy { !$0.handle.isEmpty } && Set(matches.map(\.handle)).count == 1) else { return nil }
        return matches.min { $0.lastActivity == $1.lastActivity ? $0.id < $1.id : $0.lastActivity > $1.lastActivity }
    }
    public static func resolve(agent: Agent, chats: [Chat]) -> Chat? {
        guard let chat = conversation(agent: agent, chats: chats), chat.eligible else { return nil }
        return chat
    }
    public static func status(agent: Agent, chats: [Chat]) -> String {
        if let chat = conversation(agent: agent, chats: chats) {
            if chat.businessConversation == true { return "Business conversation found · sending unavailable" }
            return chat.eligible ? "Connected" : "Conversation found · sending unavailable"
        }
        return agent.destination == nil ? "No supported conversation found" : "Saved conversation unavailable · choose again"
    }
    public static func resolve(handles: [String], chats: [Chat]) -> Chat? {
        let normalized = Set(handles.map(normalize))
        let matches = chats.filter { $0.eligible && normalized.contains(normalize($0.handle)) }
        // Contact addresses are alternatives; choose one existing conversation, never broadcast.
        return matches.min { $0.lastActivity == $1.lastActivity ? $0.id < $1.id : $0.lastActivity > $1.lastActivity }
    }
}
public enum ComparisonRange {
    public static func anchorCandidate(messages: [Message], comparison: Comparison, member: Member, comparisons: [Comparison]) -> Message? {
        guard let baseline = member.baseline else { return nil }
        let others = comparisons.filter { $0.id != comparison.id }
        let claimed = Set(others.flatMap(\.members).filter { $0.chat.id == member.chat.id }.compactMap(\.anchor?.guid))
        let attemptedAt = member.attemptedAt ?? comparison.created
        let later = others.flatMap { other in
            other.members.filter { $0.chat.id == member.chat.id && ($0.attemptedAt ?? other.created) > attemptedAt }
        }
        let boundary = later.compactMap(\.baseline).min()
        let candidates = messages.filter {
            $0.id > baseline && (boundary == nil || $0.id <= boundary!) && $0.outgoing && $0.text == comparison.prompt &&
            $0.date >= attemptedAt.addingTimeInterval(-2) && !claimed.contains($0.guid)
        }
        return candidates.count == 1 ? candidates.first : nil
    }
    public static func messages(_ messages: [Message], anchor: Anchor, next: Int64?) -> [Message] {
        var related: Set<String> = [anchor.guid]
        var selected: [Message] = []
        for message in messages.sorted(by: { $0.id < $1.id }) {
            let inRange = message.id >= anchor.rowID && (next == nil || message.id < next!)
            let linked = message.replyTo.map { related.contains($0) } ?? false
            if inRange || linked { selected.append(message); related.insert(message.guid) }
        }
        return selected
    }
    public static func nextAnchor(for comparison: Comparison, member: Member, comparisons: [Comparison]) -> Int64? {
        guard let anchor = member.anchor else { return nil }
        return comparisons.filter { $0.id != comparison.id }.flatMap(\.members).filter { $0.chat.id == member.chat.id }.compactMap(\.anchor?.rowID).filter { $0 > anchor.rowID }.min()
    }
}
public enum RecipientSet {
    public static func validate(_ members: [Member]) throws {
        var destinations: [String: String] = [:]
        for member in members {
            if let name = destinations[member.chat.id] {
                throw AppFailure.blocked("\(name) and \(member.name) share the same destination. Select one before sending.")
            }
            destinations[member.chat.id] = member.name
        }
    }
}
public enum WindowLayout {
    public static func chatWindowWidth(count: Int, surroundingWidth: Double, screenWidth: Double) -> Double {
        min(screenWidth, max(760, surroundingWidth + Double(max(1, count)) * 390 + Double(max(0, count - 1))))
    }

    public static func columns(count: Int, screenWidth: Double, screenHeight: Double) -> [SavedFrame] {
        let width = max(320, min(390, (screenWidth - 40) / Double(max(1, min(count, 3))) - 12))
        return (0..<count).map { SavedFrame(x: 20 + Double($0) * (width + 12), y: 320, width: width, height: max(400, screenHeight - 355)) }
    }
}
public enum AppFailure: LocalizedError {
    case blocked(String)
    public var errorDescription: String? { switch self { case .blocked(let text): text } }
}
