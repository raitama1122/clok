import Foundation

/// Semantic Memory (SM) — what's true (facts/preferences/skills)
/// "User prefers short answers", "Project uses Swift + PocketBase"
/// Stored as facts with confidence + last_seen
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
                facts = Array(facts.prefix(maxFacts))
            }
        }
    }
    
    func formatted(limit: Int = 15) -> String {
        facts.prefix(limit).map { "• \($0.fact) (conf: \(String(format: "%.2f", $0.confidence)))" }.joined(separator: "\n")
    }
}
