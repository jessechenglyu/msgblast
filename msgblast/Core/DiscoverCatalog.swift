import Foundation

public enum DiscoverCategory: String, CaseIterable, Sendable {
    case personal = "Personal agents"
    case research = "Research"
    case shopping = "Shopping"
}

public struct DiscoveredAgent: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let tagline: String
    public let categories: [String]
    public let website: URL
    public let smsURL: URL
    public let number: String
    public let icon: String?

    // Curated by published purpose, so broad source categories do not admit unrelated agents.
    public var discoverCategory: DiscoverCategory? {
        switch id {
        case "orchid", "sidekicks", "allora", "super", "lucas", "espa", "folk", "asmi",
             "dunnit-ai", "kicker", "ninjachat-ai", "pally", "friday", "tomo", "figment", "tinynature":
            .personal
        case "vantura", "studyarena", "noscroll", "informed-now", "just-read":
            .research
        case "ori-2", "asaply", "stiled", "allowance", "served", "avenue":
            .shopping
        default:
            nil
        }
    }
}

public struct DiscoverCatalog: Decodable, Sendable {
    public let importedOn: String
    public let agents: [DiscoveredAgent]

    public var discoverAgents: [DiscoveredAgent] { agents.filter { $0.discoverCategory != nil } }

    public func filtered(query: String, category: DiscoverCategory?) -> [DiscoveredAgent] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return discoverAgents.filter { agent in
            (category.map { agent.discoverCategory == $0 } ?? true) &&
            (query.isEmpty || [agent.name, agent.tagline, agent.website.host ?? "", agent.discoverCategory?.rawValue ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) })
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

public struct KnownAgentContacts: Sendable {
    private let names: Set<String>

    public init(agents: [DiscoveredAgent]) {
        names = Set((agents.map(\.name) + ["Fo", "Szn", "Instinct", "Poke"]).map(Self.nameKey))
    }

    public func contains(name: String) -> Bool {
        let key = Self.nameKey(name)
        return names.contains(key) || [" ai", " agent"].contains { suffix in
            key.hasSuffix(suffix) && names.contains(String(key.dropLast(suffix.count)))
        }
    }

    private static func nameKey(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
}
