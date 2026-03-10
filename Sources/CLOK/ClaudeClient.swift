import Foundation

/// Claude API client using Anthropic's Messages API with tool use
final class ClaudeClient {
    private let apiKey: String
    private let model: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String? = nil, model: String = "claude-sonnet-4-6") {
        self.apiKey = apiKey ?? Config.apiKey ?? ""
        self.model = model
    }

    var hasValidKey: Bool { !apiKey.isEmpty }

    // MARK: - Content types

    enum ContentBlock: Codable {
        case text(String)
        case toolUse(id: String, name: String, input: [String: AnyCodable])

        enum CodingKeys: String, CodingKey { case type, text, id, name, input }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            switch try c.decode(String.self, forKey: .type) {
            case "text":
                self = .text(try c.decode(String.self, forKey: .text))
            case "tool_use":
                self = .toolUse(
                    id: try c.decode(String.self, forKey: .id),
                    name: try c.decode(String.self, forKey: .name),
                    input: try c.decode([String: AnyCodable].self, forKey: .input)
                )
            default:
                self = .text("")
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let t):
                try c.encode("text", forKey: .type); try c.encode(t, forKey: .text)
            case .toolUse(let id, let name, let input):
                try c.encode("tool_use", forKey: .type); try c.encode(id, forKey: .id)
                try c.encode(name, forKey: .name); try c.encode(input, forKey: .input)
            }
        }
    }

    struct APIResponse: Codable {
        let content: [ContentBlock]
        let stopReason: String?
        enum CodingKeys: String, CodingKey { case content; case stopReason = "stop_reason" }
    }

    // MARK: - Memory extraction types

    struct MemoryExtraction: Codable {
        let facts: [String]
        let wmBullets: [String]?
        let episodeSummary: String
        let episodeOutcome: String
        let episodeTags: [String]
        let updateLst: Bool
        let profile: ProfileUpdate

        struct ProfileUpdate: Codable {
            let name: String?
            let preferences: [String]
            let expertise: [String]
            let activeProjects: [String]
            enum CodingKeys: String, CodingKey {
                case name, preferences, expertise
                case activeProjects = "active_projects"
            }
        }

        enum CodingKeys: String, CodingKey {
            case facts
            case wmBullets = "wm_bullets"
            case episodeSummary = "episode_summary"
            case episodeOutcome = "episode_outcome"
            case episodeTags = "episode_tags"
            case updateLst = "update_lst"
            case profile
        }
    }

    // MARK: - Progress callbacks

    struct ChatProgress {
        var onThinking: (() -> Void)?
        var onToolStart: ((String, [String: Any]) -> Void)?
        var onToolComplete: ((String, String) -> Void)?
        var onContinuing: (() -> Void)?
    }

    // MARK: - Main chat loop

    func chat(systemPrompt: String, messages: [(role: String, content: Any)],
              useTools: Bool = true, progress: ChatProgress? = nil) async throws -> String {
        guard hasValidKey else { throw ClaudeError.missingAPIKey }

        var requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": buildMessages(messages)
        ]
        if useTools {
            requestBody["tools"] = try JSONSerialization.jsonObject(with: ToolDefinitions.toolsJSON())
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        var allMessages = messages
        var maxToolRounds = 10
        var finalText = ""
        var hitToolLimit = false

        while maxToolRounds > 0 {
            maxToolRounds -= 1
            progress?.onThinking?()

            var body = requestBody
            body["messages"] = buildMessages(allMessages)
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ClaudeError.invalidResponse }
            if http.statusCode != 200 {
                throw ClaudeError.apiError(statusCode: http.statusCode,
                                           body: String(data: data, encoding: .utf8) ?? "Unknown")
            }

            let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
            var assistantContent: [[String: Any]] = []
            var toolResults: [[String: Any]] = []

            for block in decoded.content {
                switch block {
                case .text(let t):
                    finalText = t
                    assistantContent.append(["type": "text", "text": t])
                case .toolUse(let id, let name, let input):
                    let plainInput = input.mapValues { $0.value }
                    progress?.onToolStart?(name, plainInput)
                    let result = FileTools.execute(name: name, input: plainInput)
                    progress?.onToolComplete?(name, result)
                    assistantContent.append(["type": "tool_use", "id": id,
                                             "name": name, "input": plainInput] as [String: Any])
                    toolResults.append(["type": "tool_result", "tool_use_id": id, "content": result])
                }
            }

            allMessages.append((role: "assistant", content: assistantContent))

            if decoded.stopReason == "tool_use", !toolResults.isEmpty {
                allMessages.append((role: "user", content: toolResults))
                if maxToolRounds == 0 { hitToolLimit = true }
                progress?.onContinuing?()
            } else {
                break
            }
        }

        // If loop exhausted without a text answer, force a final no-tools call
        if hitToolLimit || finalText.isEmpty {
            progress?.onContinuing?()
            var finalBody = requestBody
            finalBody.removeValue(forKey: "tools")
            finalBody["messages"] = buildMessages(allMessages)
            request.httpBody = try JSONSerialization.data(withJSONObject: finalBody)

            let (data, _) = try await URLSession.shared.data(for: request)
            if let decoded = try? JSONDecoder().decode(APIResponse.self, from: data) {
                for block in decoded.content {
                    if case .text(let t) = block, !t.isEmpty { finalText = t; break }
                }
            }
        }

        return finalText
    }

    // MARK: - Lightweight single-shot completion (haiku, no tools)

    func complete(systemPrompt: String, userMessage: String,
                  model completionModel: String = "claude-haiku-4-5-20251001") async -> String? {
        guard hasValidKey else { return nil }
        let body: [String: Any] = [
            "model": completionModel,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
        ]
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        guard let body = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        req.httpBody = body

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(APIResponse.self, from: data) else { return nil }

        for block in decoded.content {
            if case .text(let t) = block, !t.isEmpty { return t }
        }
        return nil
    }

    // MARK: - Auto memory extraction

    func extractMemory(userInput: String, assistantResponse: String) async -> MemoryExtraction? {
        let system = "You extract structured memory from conversations. Respond ONLY with valid JSON — no explanation, no markdown."
        let prompt = """
        Extract memory updates from this exchange.

        USER: \(userInput.prefix(600))
        ASSISTANT: \(assistantResponse.prefix(1000))

        Respond with this exact JSON structure:
        {
          "facts": [],
          "wm_bullets": null,
          "episode_summary": "",
          "episode_outcome": "",
          "episode_tags": [],
          "update_lst": false,
          "profile": { "name": null, "preferences": [], "expertise": [], "active_projects": [] }
        }

        Rules:
        - facts: stable, reusable facts about the user or their environment (empty array if none)
        - wm_bullets: updated working-memory bullets if the user's focus clearly changed, null otherwise
        - episode_summary: one sentence — what the user was trying to do
        - episode_outcome: what was achieved, decided, or produced (empty string if nothing notable)
        - episode_tags: 1–3 lowercase topic tags (e.g. "coding", "writing", "research")
        - update_lst: true only if something milestone-worthy happened
        - profile.name: user's name if mentioned, null otherwise
        - profile.preferences: new communication/style preferences discovered
        - profile.expertise: skills/domains the user demonstrated knowledge of
        - profile.active_projects: project names or files the user is actively working on
        """

        guard let raw = await complete(systemPrompt: system, userMessage: prompt) else { return nil }
        let jsonStr = extractJSONString(raw)
        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MemoryExtraction.self, from: data)
    }

    // MARK: - Session greeting

    func generateSessionGreeting(profile: UserProfile, recentEvents: String,
                                  lstSummary: String, daysSinceLastSession: Int) async -> String? {
        let system = """
        You are CLOK — witty, warm, sarcastic-but-kind terminal AI. Generate a short personal greeting.
        Plain text only. No markdown. 1–2 sentences max.
        """
        var context = "Days since last session: \(daysSinceLastSession > 0 ? "\(daysSinceLastSession)" : "less than one")."
        if !recentEvents.isEmpty { context += "\nRecent activity: \(recentEvents)" }
        if !lstSummary.isEmpty   { context += "\nProject context: \(lstSummary.prefix(300))" }
        if !profile.isEmpty      { context += "\nUser: \(profile.formatted())" }
        context += "\n\nWrite a specific, personal greeting. Reference what they were working on if you know. CLOK style: warm but sarcastic."

        return await complete(systemPrompt: system, userMessage: context)
    }

    // MARK: - LST compression

    func compressLST(currentLST: String, recentEvents: [EpisodicEvent], profile: UserProfile) async -> String? {
        let system = "You maintain a concise narrative summary of a user's history with their AI assistant. Plain text only."
        let eventLines = recentEvents.map { e -> String in
            var line = e.summary
            if let o = e.outcome, !o.isEmpty { line += " → \(o)" }
            return line
        }.joined(separator: "\n")

        let prompt = """
        Update this long-term summary with recent activity.

        CURRENT SUMMARY:
        \(currentLST.isEmpty ? "(empty — this is the first summary)" : currentLST)

        RECENT EVENTS:
        \(eventLines.isEmpty ? "(none)" : eventLines)

        \(profile.isEmpty ? "" : "USER PROFILE:\n\(profile.formatted())")

        Write an updated 3–5 sentence narrative. Focus on: what the user is building/working on, how they like to work, key decisions made. Merge with current summary — don't just list recent events.
        """

        return await complete(systemPrompt: system, userMessage: prompt)
    }

    // MARK: - Helpers

    private func buildMessages(_ messages: [(role: String, content: Any)]) -> [[String: Any]] {
        messages.map { msg in
            var m: [String: Any] = ["role": msg.role]
            if let s = msg.content as? String { m["content"] = s }
            else if let arr = msg.content as? [[String: Any]] { m["content"] = arr }
            return m
        }
    }

    private func extractJSONString(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") { return trimmed }
        // Strip ```json ... ``` or ``` ... ```
        for marker in ["```json\n", "```\n", "```"] {
            if let start = trimmed.range(of: marker),
               let end = trimmed.range(of: "```", range: start.upperBound..<trimmed.endIndex) {
                return String(trimmed[start.upperBound..<end.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Fallback: find { ... }
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }
        return trimmed
    }
}

// MARK: - AnyCodable

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil()                              { value = NSNull(); return }
        if let b = try? c.decode(Bool.self)           { value = b; return }
        if let i = try? c.decode(Int.self)            { value = i; return }
        if let d = try? c.decode(Double.self)         { value = d; return }
        if let s = try? c.decode(String.self)         { value = s; return }
        if let a = try? c.decode([AnyCodable].self)   { value = a.map { $0.value }; return }
        if let o = try? c.decode([String: AnyCodable].self) { value = o.mapValues { $0.value }; return }
        value = NSNull()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull:   try c.encodeNil()
        case let b as Bool:   try c.encode(b)
        case let i as Int:    try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        default: try c.encodeNil()
        }
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:  return "ANTHROPIC_API_KEY not set. Export it: export ANTHROPIC_API_KEY=your-key"
        case .invalidResponse: return "Invalid response from API"
        case .apiError(let code, let body): return "API error \(code): \(body.prefix(200))"
        }
    }
}
