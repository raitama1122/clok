import Foundation
import LineNoise

/// CLOK CLI — main loop and command handling
final class CLI {
    private let memory: MemoryStore
    private let claude: ClaudeClient
    private var conversationHistory: [(role: String, content: Any)] = []
    private let lineNoise: LineNoise
    private var inSettingsMenu = false
    private var pendingConfirmReset = false

    private static var historyPath: String {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CLOK")
            .appendingPathComponent("history").path
    }

    init(memory: MemoryStore = MemoryStore(), claude: ClaudeClient = ClaudeClient()) {
        self.memory = memory
        self.claude = claude
        self.lineNoise = LineNoise()
        lineNoise.setHistoryMaxLength(500)
        try? FileManager.default.createDirectory(
            atPath: (Self.historyPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try? lineNoise.loadHistory(fromFile: Self.historyPath)
    }

    func run() async {
        let s = Style.self
        let banner = [
            "╭──────────────────────────────────────────────────────╮",
            "│   ██████╗██╗      ██████╗ ██╗  ██╗                   │",
            "│  ██╔════╝██║     ██╔═══██╗██║ ██╔╝                   │",
            "│  ██║     ██║     ██║   ██║█████╔╝                    │",
            "│  ██║     ██║     ██║   ██║██╔═██╗                    │",
            "│  ╚██████╗███████╗╚██████╔╝██║  ██╗                   │",
            "│   ╚═════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝                   │",
            "│                                                      │",
            "│   LLM-powered CLI with persistent memory             │",
            "│   Type 'help' for commands · 'quit' to exit          │",
            "╰──────────────────────────────────────────────────────╯"
        ]
        let padding = "  "
        print()
        for line in banner { print("\(padding)\(s.color(line, s.bold, s.brightCyan))") }
        print()

        guard claude.hasValidKey else {
            print(s.yellow("  ⚠️  ") + s.red(ClaudeError.missingAPIKey.errorDescription ?? "Missing API key"))
            print(s.dim("     Set: export ANTHROPIC_API_KEY=your-key"))
            return
        }

        // Session greeting — show if last session was > 1 hour ago
        if let lastEvent = memory.episodicMemory.events.first {
            let hoursSince = Date().timeIntervalSince(lastEvent.date) / 3600
            if hoursSince > 1 {
                let daysSince = Int(hoursSince / 24)
                let recentText = memory.episodicMemory.recent(limit: 3)
                    .map { $0.summary }.joined(separator: "; ")
                if let greeting = await claude.generateSessionGreeting(
                    profile: memory.userProfile,
                    recentEvents: recentText,
                    lstSummary: memory.longSummaryThread.summary,
                    daysSinceLastSession: daysSince
                ) {
                    print(s.cyan("  \(greeting)"))
                    print()
                }
            }
        } else {
            print(s.dim("  💡 Ask anything. I remember. I can explore your files."))
            print()
        }

        let prompt    = s.brightCyan("clok") + s.brightMagenta("> ") + s.reset
        let setPrompt = s.yellow("set") + s.dim(":") + s.brightCyan("clok") + s.brightMagenta("> ") + s.reset

        while true {
            let activePrompt = inSettingsMenu ? setPrompt : prompt
            let input: String?
            do { input = try lineNoise.getLine(prompt: activePrompt) } catch { break }
            let trimmed = input?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !trimmed.isEmpty else { continue }
            if pendingConfirmReset {
                print()
                handleConfirmReset(trimmed)
            } else if inSettingsMenu {
                lineNoise.addHistory(trimmed)
                print() // ensure clean line after raw-mode input before output
                if handleSettingsChoice(trimmed) { break }
            } else {
                lineNoise.addHistory(trimmed)
                if await handleCommand(trimmed) { break }
            }
        }

        try? FileManager.default.createDirectory(
            atPath: (Self.historyPath as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        try? lineNoise.saveHistory(toFile: Self.historyPath)
        memory.persist()
    }

    // MARK: - Command routing

    @discardableResult
    private func handleCommand(_ input: String) async -> Bool {
        let parts = input.split(separator: " ", maxSplits: 1).map(String.init)
        let cmd = parts[0].lowercased()
        let arg = parts.count > 1 ? parts[1] : ""

        switch cmd {
        case "quit", "exit", "q":
            print(Style.dim("\n  👋 See you later!\n"))
            return true
        case "help", "h":
            printHelp(); return false
        case "wm":   handleWM(arg);   return false
        case "em":   handleEM(arg);   return false
        case "sm":   handleSM(arg);   return false
        case "dm":   handleDM(arg);   return false
        case "lst":  handleLST(arg);  return false
        case "profile": handleProfile(arg); return false
        case "clear":
            conversationHistory = []
            print(Style.green("  ✓ Conversation cleared."))
            return false
        case "mem", "memory":
            printMemorySummary(); return false
        case "setting", "settings":
            if arg.isEmpty {
                showSettingsMenu(); inSettingsMenu = true
            } else if handleSettingArg(arg) {
                // subcommand handled
            } else {
                print("Usage: setting [tools|mem|reset]")
            }
            return false
        default:
            await chat(input); return false
        }
    }

    // MARK: - Chat

    private func chat(_ userInput: String) async {
        let context = memory.buildContextForClaude(userQuery: userInput)

        let cwd = FileManager.default.currentDirectoryPath
        let df = DateFormatter(); df.dateFormat = "EEEE, MMMM d, yyyy"; df.timeZone = .current
        let tf = DateFormatter(); tf.dateFormat = "h:mm a"
        let dateStr = df.string(from: Date())
        let timeStr = tf.string(from: Date())

        let systemPrompt = """
        You are CLOK — witty, sarcastic, and genuinely fun to talk to. You're an AI with persistent memory and file tools, but your vibe is sharp, playful, and a little cheeky. You banter, you tease (lightly), you make dry jokes. You're never mean — you're the friend who roasts you affectionately but still has your back.

        CURRENT DATE/TIME (user's local): \(dateStr), \(timeStr). Use this when the user asks about today, the date, day of week, or time-sensitive context.

        PERSONALITY: Quick-witted, sarcastic in a warm way, self-aware. You might roll your eyes at obvious questions but answer them anyway. You use humor when it fits. Keep it light — never cruel or condescending. You're genuinely helpful beneath the sass.

        You have file tools: file_list (ls), file_search (find by name), file_grep (search content), file_mkdir, file_list_by_date, file_read (supports start_line for pagination), file_write, file_summarize. Use them when the user asks about their filesystem. Current working directory: \(cwd)

        You have web_search: Use it when the user asks about current events, news, facts, or anything that needs up-to-date info from the internet.

        Memory is updated automatically in the background — you don't need to suggest "sm add" or "em add" anymore. Just focus on helping the user.

        OUTPUT FORMAT: You're in a terminal. No markdown — no **bold**, *italic*, # headers, or ``` code blocks. Use plain text, simple bullets (•), line breaks, and maybe CAPS for emphasis. Keep it readable in a raw terminal. Never output "clok>" — that's the prompt.

        --- MEMORY CONTEXT ---
        \(context)
        --- END CONTEXT ---
        """

        conversationHistory.append((role: "user", content: userInput))

        let thinkingPhrases = ["Let me check...", "One sec...", "Looking into it...", "On it...", "Thinking..."]
        var roundIndex = 0

        let progress = ClaudeClient.ChatProgress(
            onThinking: {
                roundIndex += 1
                let msg = roundIndex == 1 ? "Got it. " + (thinkingPhrases.randomElement() ?? "Thinking...") : "Putting it together..."
                print(Style.dim("  \(msg)"))
            },
            onToolStart: { name, input in
                print(Style.cyan("  → ") + Style.dim(ToolStatus.describeStart(name: name, input: input)))
            },
            onToolComplete: { name, result in
                print(Style.green("  ✓ ") + Style.dim(ToolStatus.describeComplete(name: name, result: result)))
            },
            onContinuing: { }
        )

        do {
            let response = try await claude.chat(
                systemPrompt: systemPrompt,
                messages: conversationHistory,
                useTools: true,
                progress: progress
            )

            conversationHistory.append((role: "assistant", content: response))
            print("\n\(TerminalFormat.format(response))\n")

            // Auto-extract memory in background — non-blocking
            let capturedInput = userInput
            let capturedResponse = response
            Task {
                await extractAndPersistMemory(userInput: capturedInput, response: capturedResponse)
            }

        } catch {
            print(Style.red("  ✗ Error: \(error.localizedDescription)"))
        }
    }

    // MARK: - Background memory extraction

    private func extractAndPersistMemory(userInput: String, response: String) async {
        guard let extraction = await claude.extractMemory(
            userInput: userInput, assistantResponse: response
        ) else { return }

        // Semantic facts
        for fact in extraction.facts where !fact.isEmpty {
            memory.semanticMemory.add(fact: fact)
        }

        // Working memory update (only if extraction says focus changed)
        if let bullets = extraction.wmBullets, !bullets.isEmpty {
            memory.workingMemory.update(with: bullets)
        }

        // Real episodic entry
        if !extraction.episodeSummary.isEmpty {
            memory.episodicMemory.add(
                summary: extraction.episodeSummary,
                outcome: extraction.episodeOutcome.isEmpty ? nil : extraction.episodeOutcome,
                tags: extraction.episodeTags
            )
        }

        // User profile updates
        if let name = extraction.profile.name, !name.isEmpty {
            memory.userProfile.name = name
        }
        memory.userProfile.mergePreferences(extraction.profile.preferences)
        memory.userProfile.mergeExpertise(extraction.profile.expertise)
        memory.userProfile.mergeProjects(extraction.profile.activeProjects)
        if !extraction.profile.preferences.isEmpty || !extraction.profile.expertise.isEmpty
            || !extraction.profile.activeProjects.isEmpty || extraction.profile.name != nil {
            memory.userProfile.updatedAt = Date()
        }

        memory.persist()

        // Compress LST every 20 episodic events
        if memory.episodicMemory.events.count > 0 && memory.episodicMemory.events.count % 20 == 0 {
            await compressLST()
        }
    }

    private func compressLST() async {
        let recentEvents = memory.episodicMemory.recent(limit: 20)
        guard let newSummary = await claude.compressLST(
            currentLST: memory.longSummaryThread.summary,
            recentEvents: recentEvents,
            profile: memory.userProfile
        ), !newSummary.isEmpty else { return }
        memory.longSummaryThread.update(with: newSummary)
        memory.persist()
    }

    // MARK: - Settings menu

    private func showSettingsMenu() {
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
        print(s.dim("  Enter 1–4 (or tools, mem, reset, back) at the prompt below."))
        print()
    }

    private func handleSettingsChoice(_ input: String) -> Bool {
        let choice = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch choice {
        case "1", "tools":
            Settings.viewTools()
        case "2", "mem", "memory":
            Settings.viewMemorySummary(memory)
        case "3", "reset":
            inSettingsMenu = false
            pendingConfirmReset = true
            print(Style.yellow("  ⚠ This will delete ALL memory. Continue? ") + Style.dim("[y/N]: "))
        case "4", "back", "b", "quit", "q", "exit":
            inSettingsMenu = false
            print(Style.dim("  Exited settings."))
        default:
            // Unknown input — exit settings so the user isn't trapped
            inSettingsMenu = false
            print(Style.dim("  Exited settings. (use 'setting' to return)"))
        }
        return false
    }

    private func handleConfirmReset(_ input: String) {
        pendingConfirmReset = false
        if ["y", "yes"].contains(input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) {
            memory.reset()
            print(Style.green("  ✓ All memory has been reset."))
        }
    }

    private func handleSettingArg(_ arg: String) -> Bool {
        let sub = arg.trimmingCharacters(in: .whitespaces).lowercased()
        switch sub {
        case "1", "tools":   Settings.viewTools(); return true
        case "2", "mem", "memory": Settings.viewMemorySummary(memory); return true
        case "3", "reset":
            pendingConfirmReset = true
            print()
            print(Style.yellow("  ⚠ This will delete ALL memory. Continue? ") + Style.dim("[y/N]: "))
            return true
        case "4", "back": return true
        default: return Settings.runSubcommand(sub, memory: memory)
        }
    }

    // MARK: - Help

    private func printHelp() {
        let s = Style.self
        print()
        print(s.bold(s.cyan("  Commands")))
        print(s.dim("  ─────────────────────────────────────────"))
        print("    " + s.yellow("<message>") + "          Chat with Claude (memory + tools)")
        print("    " + s.yellow("profile") + "            View/edit user profile")
        print("    " + s.yellow("wm") + " [bullets]       View/set Working Memory (use | to separate)")
        print("    " + s.yellow("em") + " [add ...]       Add/view Episodic Memory")
        print("    " + s.yellow("sm") + " [add ...]       Add/view Semantic Memory")
        print("    " + s.yellow("dm") + " [add ...]       Add/view Document Memory")
        print("    " + s.yellow("lst") + " [text]         View/set Long Summary Thread")
        print("    " + s.yellow("mem") + "                Show memory summary")
        print("    " + s.yellow("setting") + "            Settings")
        print("    " + s.yellow("clear") + "              Clear conversation history")
        print("    " + s.yellow("help") + "               This help")
        print("    " + s.yellow("quit") + "               Exit CLOK")
        print()
        print(s.dim("  Memory updates automatically after each chat — no manual commands needed."))
        print()
    }

    // MARK: - Memory command handlers

    private func handleWM(_ arg: String) {
        if arg.isEmpty {
            let formatted = memory.workingMemory.formatted()
            print("Working Memory:\n\(formatted.isEmpty ? "(empty)" : formatted)")
        } else {
            let bullets = arg.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            memory.workingMemory.update(with: bullets.filter { !$0.isEmpty })
            memory.persist()
            print(Style.green("  ✓ Updated WM with \(bullets.count) bullet(s)."))
        }
    }

    private func handleEM(_ arg: String) {
        if arg.isEmpty {
            print("Episodic Memory:\n\(memory.episodicMemory.formatted(limit: 10))")
        } else if arg.lowercased().hasPrefix("add ") {
            let summary = String(arg.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            memory.episodicMemory.add(summary: summary)
            memory.persist()
            print(Style.green("  ✓ Added episodic event."))
        } else {
            print("Usage: em add <summary>")
        }
    }

    private func handleSM(_ arg: String) {
        if arg.isEmpty {
            print("Semantic Memory:\n\(memory.semanticMemory.formatted(limit: 20))")
        } else if arg.lowercased().hasPrefix("add ") {
            let fact = String(arg.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            memory.semanticMemory.add(fact: fact)
            memory.persist()
            print(Style.green("  ✓ Added semantic fact."))
        } else {
            print("Usage: sm add <fact>")
        }
    }

    private func handleDM(_ arg: String) {
        if arg.isEmpty {
            print("Document Memory:\n\(memory.documentMemory.formatted(limit: 5))")
        } else if arg.lowercased().hasPrefix("add ") {
            let rest = String(arg.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            if let idx = rest.firstIndex(of: " ") {
                let source = String(rest[..<idx])
                let content = String(rest[rest.index(after: idx)...])
                memory.documentMemory.add(source: source, content: content)
                memory.persist()
                print(Style.green("  ✓ Added document chunk."))
            } else {
                print("Usage: dm add <source> <content>")
            }
        } else {
            print("Usage: dm add <source> <content>")
        }
    }

    private func handleLST(_ arg: String) {
        if arg.isEmpty {
            print("Long Summary Thread:\n\(memory.longSummaryThread.formatted())")
        } else {
            memory.longSummaryThread.update(with: arg)
            memory.persist()
            print(Style.green("  ✓ Updated LST."))
        }
    }

    private func handleProfile(_ arg: String) {
        let s = Style.self
        if arg.isEmpty {
            print()
            print(s.bold(s.cyan("  User Profile")))
            print(s.dim("  ─────────────────"))
            if memory.userProfile.isEmpty {
                print(s.dim("  (empty — will fill in automatically as you chat)"))
            } else {
                print("  \(memory.userProfile.formatted().replacingOccurrences(of: "\n", with: "\n  "))")
            }
            print()
        } else if arg.lowercased().hasPrefix("name ") {
            memory.userProfile.name = String(arg.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            memory.persist()
            print(Style.green("  ✓ Name updated."))
        } else if arg.lowercased().hasPrefix("pref ") {
            let pref = String(arg.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            memory.userProfile.mergePreferences([pref])
            memory.persist()
            print(Style.green("  ✓ Preference added."))
        } else {
            print("Usage: profile | profile name <name> | profile pref <preference>")
        }
    }

    private func printMemorySummary() {
        let s = Style.self
        print()
        print(s.bold(s.cyan("  Memory Summary")))
        print(s.dim("  ─────────────────"))
        if !memory.userProfile.isEmpty {
            print("    " + s.yellow("Profile") + ": " + memory.userProfile.formatted().components(separatedBy: "\n").first!)
        }
        print("    " + s.yellow("WM") + ":  \(memory.workingMemory.bullets.count) bullets")
        print("    " + s.yellow("EM") + ":  \(memory.episodicMemory.events.count) events")
        print("    " + s.yellow("SM") + ":  \(memory.semanticMemory.facts.count) facts")
        print("    " + s.yellow("DM") + ":  \(memory.documentMemory.chunks.count) chunks")
        print("    " + s.yellow("LST") + ": \(memory.longSummaryThread.summary.isEmpty ? "empty" : "\(memory.longSummaryThread.summary.count) chars")")
        print()
    }
}
