import Foundation

/// Episodic Memory (EM) — what happened (events)
/// "On 2026-03-05 user asked for X; we decided Y; outcome Z"
/// Stored as atomic events, not full transcripts
struct EpisodicEvent: Codable, Identifiable {
    let id: UUID
    let date: Date
    let summary: String
    let outcome: String?
    
    init(id: UUID = UUID(), date: Date = Date(), summary: String, outcome: String? = nil) {
        self.id = id
        self.date = date
        self.summary = summary
        self.outcome = outcome
    }
}

struct EpisodicMemory: Codable {
    var events: [EpisodicEvent]
    let maxEvents: Int
    
    init(events: [EpisodicEvent] = [], maxEvents: Int = 500) {
        self.events = events
        self.maxEvents = maxEvents
    }
    
    mutating func add(summary: String, outcome: String? = nil) {
        let event = EpisodicEvent(summary: summary, outcome: outcome)
        events.insert(event, at: 0)
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
    }
    
    func recent(limit: Int = 10) -> [EpisodicEvent] {
        Array(events.prefix(limit))
    }
    
    func formatted(limit: Int = 5) -> String {
        recent(limit: limit).map { event in
            let df = DateFormatter()
            df.dateStyle = .short
            let dateStr = df.string(from: event.date)
            var line = "\(dateStr): \(event.summary)"
            if let outcome = event.outcome {
                line += " → \(outcome)"
            }
            return line
        }.joined(separator: "\n")
    }
}
