import Foundation

/// ANSI colors and styles for terminal output
enum Style {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    
    // Colors
    static let black = "\u{001B}[30m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
    static let white = "\u{001B}[37m"
    
    // Bright
    static let brightBlack = "\u{001B}[90m"
    static let brightRed = "\u{001B}[91m"
    static let brightGreen = "\u{001B}[92m"
    static let brightYellow = "\u{001B}[93m"
    static let brightBlue = "\u{001B}[94m"
    static let brightMagenta = "\u{001B}[95m"
    static let brightCyan = "\u{001B}[96m"
    static let brightWhite = "\u{001B}[97m"
    
    /// Wrap text with ANSI code(s), then reset. Codes can be combined: bold + brightCyan
    static func color(_ text: String, _ codes: String...) -> String {
        "\(codes.joined())\(text)\(reset)"
    }
    
    static func bold(_ text: String) -> String { color(text, bold) }
    static func dim(_ text: String) -> String { color(text, dim) }
    
    static func red(_ text: String) -> String { color(text, Self.red) }
    static func green(_ text: String) -> String { color(text, Self.green) }
    static func yellow(_ text: String) -> String { color(text, Self.yellow) }
    static func blue(_ text: String) -> String { color(text, Self.blue) }
    static func magenta(_ text: String) -> String { color(text, Self.magenta) }
    static func cyan(_ text: String) -> String { color(text, Self.cyan) }
    
    static func brightCyan(_ text: String) -> String { color(text, Self.brightCyan) }
    static func brightGreen(_ text: String) -> String { color(text, Self.brightGreen) }
    static func brightYellow(_ text: String) -> String { color(text, Self.brightYellow) }
    static func brightMagenta(_ text: String) -> String { color(text, Self.brightMagenta) }
}
