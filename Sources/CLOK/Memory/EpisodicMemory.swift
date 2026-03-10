import Foundation

/// Episodic Memory (EM) — what happened (events)
/// "On 2026-03-05 user asked for X; we decided Y; outcome Z"
/// Stored as atomic events with topic tags for relevance filtering
struct EpisodicEvent: Codable, Identifiable {
    let id: UUID
    let date: Date
    let summary: String
    let outcome: String?
    let tags: [String]  // lowercase topic tags e.g. ["coding", "swift", "refactor"]

    init(id: UUID = UUID(), date: Date = Date(),
         summary: String, outcome: String? = nil, tags: [String] = []) {
        self.id = id
        self.date = date
        self.summary = summary
        self.outcome = outcome
        self.tags = tags.map { $0.lowercased() }
    }
}

struct EpisodicMemory: Codable {
    var events: [EpisodicEvent]
    let maxEvents: Int

    init(events: [EpisodicEvent] = [], maxEvents: Int = 500) {
        self.events = events
        self.maxEvents = maxEvents
    }

    mutating func add(summary: String, outcome: String? = nil, tags: [String] = []) {
        let event = EpisodicEvent(summary: summary, outcome: outcome, tags: tags)
        events.insert(event, at: 0)
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
    }

    func recent(limit: Int = 10) -> [EpisodicEvent] {
        Array(events.prefix(limit))
    }

    /// Events ranked by tag overlap with query + recency
    func relevantEvents(for query: String, limit: Int = 5) -> [EpisodicEvent] {
        let words = Set(
            query.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 2 }
        )
        guard !words.isEmpty else { return recent(limit: limit) }

        return events
            .map { event -> (EpisodicEvent, Double) in
                let tagOverlap = Double(Set(event.tags).intersection(words).count)
                let summaryWords = Set(event.summary.lowercased().components(separatedBy: .whitespacesAndNewlines))
                let summaryOverlap = Double(summaryWords.intersection(words).count) * 0.5
                // Recency bonus: events within last 7 days get a boost
                let daysSince = Date().timeIntervalSince(event.date) / 86400
                let recencyBonus = daysSince < 7 ? 1.0 : 0.0
                return (event, tagOverlap + summaryOverlap + recencyBonus)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    func formatted(limit: Int = 5) -> String {
        recent(limit: limit).map { event in
            let df = DateFormatter()
            df.dateStyle = .short
            let dateStr = df.string(from: event.date)
            var line = "\(dateStr): \(event.summary)"
            if let outcome = event.outcome { line += " → \(outcome)" }
            return line
        }.joined(separator: "\n")
    }
}
