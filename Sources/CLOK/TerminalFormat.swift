import Foundation

/// Converts markdown-heavy text to terminal-friendly plain text
enum TerminalFormat {
    
    static func format(_ text: String) -> String {
        var result = text
        
        // **bold** or __bold__ → plain (remove markers)
        result = result.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"__([^_]+)__"#, with: "$1", options: .regularExpression)
        
        // *italic* (single asterisk, do after **)
        result = result.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
        
        // # ## ### headers → remove hash prefix (match at start or after newline)
        result = result.replacingOccurrences(of: #"(^|\n)#{1,6}\s+"#, with: "$1", options: .regularExpression)
        
        // ```code blocks``` → remove fence lines
        result = result.replacingOccurrences(of: #"```[\w]*\n"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n```\s*"#, with: "\n", options: .regularExpression)
        
        // [link text](url) → link text (url)
        result = result.replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: "$1 ($2)", options: .regularExpression)
        
        // - or * at line start (markdown bullet) → •
        result = result.replacingOccurrences(of: #"(^|\n)\s*[-*]\s+"#, with: "$1  • ", options: .regularExpression)
        
        // Collapse excessive newlines (3+ → 2)
        result = result.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove trailing prompt-like text that could cause "clok> clok>"
        if result.hasSuffix("clok> ") {
            result = String(result.dropLast(6)).trimmingCharacters(in: .whitespaces)
        } else if result.hasSuffix("clok>") {
            result = String(result.dropLast(5)).trimmingCharacters(in: .whitespaces)
        }
        return result
    }
}
