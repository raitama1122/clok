import Foundation

/// Load API keys from env or config file
enum Config {
    static var apiKey: String? {
        envOrConfig("ANTHROPIC_API_KEY")
    }
    
    static var serperApiKey: String? {
        envOrConfig("SERPER_API_KEY")
    }
    
    private static func envOrConfig(_ key: String) -> String? {
        let envKey = key
        if let env = ProcessInfo.processInfo.environment[envKey], !env.isEmpty {
            return env
        }
        return loadFromConfigFile(key: key)
    }
    
    private static func loadFromConfigFile(key: String) -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".clok")
            .appendingPathComponent("config")
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return nil }
        let prefix = "\(key)="
        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
