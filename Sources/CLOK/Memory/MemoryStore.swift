import Foundation

/// Unified memory store — persists all memory types to disk
final class MemoryStore {
    private let fileManager = FileManager.default
    private let baseURL: URL

    var storagePath: String { baseURL.path }

    var userProfile: UserProfile
    var workingMemory: WorkingMemory
    var episodicMemory: EpisodicMemory
    var semanticMemory: SemanticMemory
    var documentMemory: DocumentMemory
    var longSummaryThread: LongSummaryThread

    init(baseURL: URL? = nil) {
        let url = baseURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CLOK", isDirectory: true)
        self.baseURL = url

        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)

        self.userProfile        = Self.load(UserProfile.self,        from: url.appendingPathComponent("profile.json"))  ?? UserProfile()
        self.workingMemory      = Self.load(WorkingMemory.self,      from: url.appendingPathComponent("wm.json"))       ?? WorkingMemory()
        self.episodicMemory     = Self.load(EpisodicMemory.self,     from: url.appendingPathComponent("em.json"))       ?? EpisodicMemory()
        self.semanticMemory     = Self.load(SemanticMemory.self,     from: url.appendingPathComponent("sm.json"))       ?? SemanticMemory()
        self.documentMemory     = Self.load(DocumentMemory.self,     from: url.appendingPathComponent("dm.json"))       ?? DocumentMemory()
        self.longSummaryThread  = Self.load(LongSummaryThread.self,  from: url.appendingPathComponent("lst.json"))      ?? LongSummaryThread()
    }

    private static func load<T: Codable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Codable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url)
    }

    func persist() {
        save(userProfile,       to: baseURL.appendingPathComponent("profile.json"))
        save(workingMemory,     to: baseURL.appendingPathComponent("wm.json"))
        save(episodicMemory,    to: baseURL.appendingPathComponent("em.json"))
        save(semanticMemory,    to: baseURL.appendingPathComponent("sm.json"))
        save(documentMemory,    to: baseURL.appendingPathComponent("dm.json"))
        save(longSummaryThread, to: baseURL.appendingPathComponent("lst.json"))
    }

    /// Reset all memory to empty state
    func reset() {
        userProfile       = UserProfile()
        workingMemory     = WorkingMemory()
        episodicMemory    = EpisodicMemory()
        semanticMemory    = SemanticMemory()
        documentMemory    = DocumentMemory()
        longSummaryThread = LongSummaryThread()
        persist()
    }

    /// Build context for Claude — ordered by permanence, filtered by relevance
    func buildContextForClaude(userQuery: String, includeLST: Bool = true) -> String {
        var parts: [String] = []

        // 1. User profile — stable persona layer, always first
        if !userProfile.isEmpty {
            parts.append("## User Profile")
            parts.append(userProfile.formatted())
            parts.append("")
        }

        // 2. Working memory — current session focus
        if !workingMemory.bullets.isEmpty {
            parts.append("## Working Memory (current focus)")
            parts.append(workingMemory.formatted())
            parts.append("")
        }

        // 3. Long summary thread — project/relationship narrative
        if includeLST && !longSummaryThread.summary.isEmpty {
            parts.append("## Long Summary (history & projects)")
            parts.append(longSummaryThread.formatted())
            parts.append("")
        }

        // 4. Relevant semantic facts — query-scored, recency-decayed
        let relevantFacts = semanticMemory.relevantFacts(for: userQuery, limit: 12)
        if !relevantFacts.isEmpty {
            parts.append("## Known Facts & Preferences")
            parts.append(relevantFacts.map { "• \($0.fact)" }.joined(separator: "\n"))
            parts.append("")
        }

        // 5. Relevant episodic events — tag + keyword scored
        let relevantEvents = episodicMemory.relevantEvents(for: userQuery, limit: 5)
        if !relevantEvents.isEmpty {
            let df = DateFormatter(); df.dateStyle = .short
            parts.append("## Recent Activity")
            parts.append(relevantEvents.map { e in
                var line = "\(df.string(from: e.date)): \(e.summary)"
                if let outcome = e.outcome { line += " → \(outcome)" }
                return line
            }.joined(separator: "\n"))
            parts.append("")
        }

        // 6. Relevant documents — TF-IDF scored
        let relevantDocs = documentMemory.search(query: userQuery)
        if !relevantDocs.isEmpty {
            parts.append("## Relevant Documents")
            for chunk in relevantDocs {
                parts.append("[\(chunk.source)] \(chunk.content.prefix(400))\(chunk.content.count > 400 ? "..." : "")")
            }
            parts.append("")
        }

        return parts.joined(separator: "\n")
    }
}
