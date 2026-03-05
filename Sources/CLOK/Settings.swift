import Foundation

/// Settings — tools, memory summary, reset (menu handled by CLI main loop)
enum Settings {
    
    /// Show settings menu (for `clok setting` from command line)
    static func showMenu() {
        let s = Style.self
        print()
        print(s.bold(s.brightMagenta("  ╭─────────────────────────────╮")))
        print(s.bold(s.brightMagenta("  │")) + "   " + s.bold("CLOK Settings") + "   " + s.bold(s.brightMagenta("│")))
        print(s.bold(s.brightMagenta("  ╰─────────────────────────────╯")))
        print()
        print("    " + s.cyan("1") + ". View available tools")
        print("    " + s.cyan("2") + ". View memory summary")
        print("    " + s.cyan("3") + ". Reset memory")
        print("    " + s.cyan("4") + ". Back")
        print()
        print(s.dim("  Run: clok setting tools | clok setting mem | clok setting reset"))
        print()
    }
    
    /// Run with direct subcommand (e.g. `clok setting mem`)
    static func runSubcommand(_ sub: String, memory: MemoryStore) -> Bool {
        switch sub.lowercased() {
        case "tools":
            viewTools()
            return true
        case "mem", "memory":
            viewMemorySummary(memory)
            return true
        case "reset":
            // Reset confirm is handled by CLI when using direct command
            memory.reset()
            print(Style.green("  ✓ All memory has been reset."))
            return true
        default:
            return false
        }
    }
    
    static func viewTools() {
        let s = Style.self
        let desc: [(String, String)] = [
            ("file_list", "List directory contents (like ls)"),
            ("file_search", "Search files by name pattern"),
            ("file_grep", "Search file contents for text"),
            ("file_mkdir", "Create directory"),
            ("file_list_by_date", "List files sorted by date (newest/oldest)"),
            ("file_read", "Read file contents"),
            ("file_write", "Write content to file"),
            ("file_summarize", "Summarize files/dirs (names, sizes)"),
            ("web_search", "Search the web for current info")
        ]
        print()
        print(s.bold(s.cyan("  Available tools")))
        print(s.dim("  ─────────────────────────────────────"))
        for (name, d) in desc {
            print("    " + s.yellow(name) + s.dim(": ") + d)
        }
        print()
        print(s.dim("  Claude uses these automatically when you ask about files."))
        print()
    }
    
    static func viewMemorySummary(_ memory: MemoryStore) {
        let s = Style.self
        print()
        print(s.bold(s.cyan("  Memory Summary")))
        print(s.dim("  ─────────────────"))
        print("    " + s.yellow("WM") + ":  \(memory.workingMemory.bullets.count) bullets")
        print("    " + s.yellow("EM") + ":  \(memory.episodicMemory.events.count) events")
        print("    " + s.yellow("SM") + ":  \(memory.semanticMemory.facts.count) facts")
        print("    " + s.yellow("DM") + ":  \(memory.documentMemory.chunks.count) chunks")
        print("    " + s.yellow("LST") + ": \(memory.longSummaryThread.summary.isEmpty ? "empty" : "\(memory.longSummaryThread.summary.count) chars")")
        print()
        print(s.dim("  Storage: ") + memory.storagePath)
        print()
    }
}
