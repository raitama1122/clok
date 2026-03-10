import Foundation

/// Semantic Memory (SM) — what's true (facts/preferences/skills)
/// "User prefers short answers", "Project uses Swift + PocketBase"
/// Stored as facts with confidence + last_seen; confidence decays over time
struct SemanticFact: Codable, Identifiable {
    let id: UUID
    var fact: String
    var confidence: Double
    var lastSeen: Date

    init(id: UUID = UUID(), fact: String, confidence: Double = 1.0, lastSeen: Date = Date()) {
        self.id = id
        self.fact = fact
        self.confidence = min(max(confidence, 0), 1)
        self.lastSeen = lastSeen
    }

    /// Confidence decayed by recency — halves every ~180 days
    var effectiveConfidence: Double {
        let daysSince = Date().timeIntervalSince(lastSeen) / 86400
        let decay = exp(-daysSince / 180)
        return confidence * decay
    }

    mutating func reinforce() {
        lastSeen = Date()
        confidence = min(confidence + 0.1, 1.0)
    }
}

struct SemanticMemory: Codable {
    var facts: [SemanticFact]
    let maxFacts: Int

    init(facts: [SemanticFact] = [], maxFacts: Int = 200) {
        self.facts = facts
        self.maxFacts = maxFacts
    }

    mutating func add(fact: String, confidence: Double = 1.0) {
        if let idx = facts.firstIndex(where: { $0.fact.lowercased() == fact.lowercased() }) {
            facts[idx].reinforce()
            facts[idx].fact = fact
        } else {
            facts.insert(SemanticFact(fact: fact, confidence: confidence), at: 0)
            if facts.count > maxFacts {
                // Drop lowest-confidence facts when over limit
                facts = facts.sorted { $0.effectiveConfidence > $1.effectiveConfidence }
                facts = Array(facts.prefix(maxFacts))
            }
        }
    }

    /// Top facts sorted by decayed confidence — no internal scores shown to Claude
    func formatted(limit: Int = 15) -> String {
        facts.sorted { $0.effectiveConfidence > $1.effectiveConfidence }
            .prefix(limit)
            .map { "• \($0.fact)" }
            .joined(separator: "\n")
    }

    /// Query-relevant facts: keyword overlap + recency decay blended
    func relevantFacts(for query: String, limit: Int = 12) -> [SemanticFact] {
        let words = Set(
            query.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { $0.count > 2 }
        )
        guard !words.isEmpty else {
            return Array(facts.sorted { $0.effectiveConfidence > $1.effectiveConfidence }.prefix(limit))
        }
        return facts
            .map { fact -> (SemanticFact, Double) in
                let factWords = Set(fact.fact.lowercased().components(separatedBy: .whitespacesAndNewlines))
                let overlap = Double(factWords.intersection(words).count)
                let score = fact.effectiveConfidence + overlap * 0.4
                return (fact, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
}
