import Foundation

/// Long Summary Thread (LST) — optional but powerful
/// A rolling narrative summary of the relationship/project
/// Updated only when needed
struct LongSummaryThread: Codable {
    var summary: String
    var updatedAt: Date
    
    init(summary: String = "", updatedAt: Date = Date()) {
        self.summary = summary
        self.updatedAt = updatedAt
    }
    
    mutating func update(with newSummary: String) {
        summary = newSummary
        updatedAt = Date()
    }
    
    func formatted() -> String {
        summary.isEmpty ? "(No summary yet)" : summary
    }
}
