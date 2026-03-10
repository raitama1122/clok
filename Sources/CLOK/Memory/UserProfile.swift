import Foundation

/// Stable user profile — always injected into every prompt
/// Separate from SemanticMemory (which is for transient/contextual facts)
struct UserProfile: Codable {
    var name: String?
    var timezone: String?
    var preferences: [String]   // communication style, verbosity, tone
    var expertise: [String]     // known skills / domains
    var activeProjects: [String]
    var updatedAt: Date

    init(name: String? = nil, timezone: String? = nil,
         preferences: [String] = [], expertise: [String] = [],
         activeProjects: [String] = [], updatedAt: Date = Date()) {
        self.name = name
        self.timezone = timezone
        self.preferences = preferences
        self.expertise = expertise
        self.activeProjects = activeProjects
        self.updatedAt = updatedAt
    }

    var isEmpty: Bool {
        name == nil && preferences.isEmpty && expertise.isEmpty && activeProjects.isEmpty
    }

    func formatted() -> String {
        var lines: [String] = []
        if let name = name { lines.append("Name: \(name)") }
        if !preferences.isEmpty { lines.append("Preferences: \(preferences.joined(separator: ", "))") }
        if !expertise.isEmpty { lines.append("Expertise: \(expertise.joined(separator: ", "))") }
        if !activeProjects.isEmpty { lines.append("Active projects: \(activeProjects.joined(separator: ", "))") }
        return lines.joined(separator: "\n")
    }

    mutating func mergePreferences(_ new: [String]) {
        for p in new where !preferences.contains(p) { preferences.append(p) }
    }
    mutating func mergeExpertise(_ new: [String]) {
        for e in new where !expertise.contains(e) { expertise.append(e) }
    }
    mutating func mergeProjects(_ new: [String]) {
        for p in new where !activeProjects.contains(p) { activeProjects.append(p) }
    }
}
