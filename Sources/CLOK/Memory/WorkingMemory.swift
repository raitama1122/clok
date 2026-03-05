import Foundation

/// Working Memory (WM) — tiny, always-on
/// Current goal, constraints, user prefs needed right now
/// Size: 5–20 bullet lines max, updated every turn
struct WorkingMemory: Codable {
    var bullets: [String]
    var updatedAt: Date
    
    init(bullets: [String] = [], updatedAt: Date = Date()) {
        self.bullets = Array(bullets.prefix(20))
        self.updatedAt = updatedAt
    }
    
    mutating func update(with newBullets: [String]) {
        bullets = Array(newBullets.prefix(20))
        updatedAt = Date()
    }
    
    func formatted() -> String {
        bullets.enumerated().map { "• \($0.element)" }.joined(separator: "\n")
    }
}
