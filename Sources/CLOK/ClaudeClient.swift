import Foundation

/// Claude API client using Anthropic's Messages API with tool use
/// Uses claude-sonnet-4-6 for best speed + intelligence balance
final class ClaudeClient {
    private let apiKey: String
    private let model: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!
    
    init(apiKey: String? = nil, model: String = "claude-sonnet-4-6") {
        self.apiKey = apiKey ?? Config.apiKey ?? ""
        self.model = model
    }
    
    var hasValidKey: Bool { !apiKey.isEmpty }
    
    enum ContentBlock: Codable {
        case text(String)
        case toolUse(id: String, name: String, input: [String: AnyCodable])
        
        enum CodingKeys: String, CodingKey {
            case type, text, id, name, input
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)
            switch type {
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
                try c.encode("text", forKey: .type)
                try c.encode(t, forKey: .text)
            case .toolUse(let id, let name, let input):
                try c.encode("tool_use", forKey: .type)
                try c.encode(id, forKey: .id)
                try c.encode(name, forKey: .name)
                try c.encode(input, forKey: .input)
            }
        }
    }
    
    struct APIResponse: Codable {
        let content: [ContentBlock]
        let stopReason: String?
        
        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }
    
    /// Progress callbacks for interactive feedback
    struct ChatProgress {
        var onThinking: (() -> Void)?
        var onToolStart: ((String, [String: Any]) -> Void)?
        var onToolComplete: ((String, String) -> Void)?
        var onContinuing: (() -> Void)?
    }
    
    /// Chat with optional tool use. Executes file tools when Claude requests them.
    func chat(systemPrompt: String, messages: [(role: String, content: Any)], useTools: Bool = true, progress: ChatProgress? = nil) async throws -> String {
        guard hasValidKey else {
            throw ClaudeError.missingAPIKey
        }
        
        var requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": buildMessages(messages)
        ]
        
        if useTools {
            let toolsData = ToolDefinitions.toolsJSON()
            requestBody["tools"] = try JSONSerialization.jsonObject(with: toolsData)
        }
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        var allMessages = messages
        var maxToolRounds = 5
        var finalText = ""
        
        while maxToolRounds > 0 {
            maxToolRounds -= 1
            
            progress?.onThinking?()
            
            var body = requestBody
            body["messages"] = buildMessages(allMessages)
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                throw ClaudeError.invalidResponse
            }
            
            if http.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
                throw ClaudeError.apiError(statusCode: http.statusCode, body: errorBody)
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
                    assistantContent.append([
                        "type": "tool_use",
                        "id": id,
                        "name": name,
                        "input": plainInput
                    ] as [String: Any])
                    toolResults.append([
                        "type": "tool_result",
                        "tool_use_id": id,
                        "content": result
                    ])
                }
            }
            
            allMessages.append((role: "assistant", content: assistantContent))
            
            if decoded.stopReason == "tool_use", !toolResults.isEmpty {
                allMessages.append((role: "user", content: toolResults))
                progress?.onContinuing?()
            } else {
                break
            }
        }
        
        return finalText
    }
    
    private func buildMessages(_ messages: [(role: String, content: Any)]) -> [[String: Any]] {
        messages.map { msg in
            var m: [String: Any] = ["role": msg.role]
            if let s = msg.content as? String {
                m["content"] = s
            } else if let arr = msg.content as? [[String: Any]] {
                m["content"] = arr
            }
            return m
        }
    }
}

/// Helper for encoding arbitrary JSON values
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = NSNull(); return }
        if let b = try? c.decode(Bool.self) { value = b; return }
        if let i = try? c.decode(Int.self) { value = i; return }
        if let d = try? c.decode(Double.self) { value = d; return }
        if let s = try? c.decode(String.self) { value = s; return }
        if let a = try? c.decode([AnyCodable].self) { value = a.map { $0.value }; return }
        if let o = try? c.decode([String: AnyCodable].self) { value = o.mapValues { $0.value }; return }
        value = NSNull()
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let b as Bool: try c.encode(b)
        case let i as Int: try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        default: try c.encodeNil()
        }
    }
}

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, body: String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "ANTHROPIC_API_KEY not set. Export it: export ANTHROPIC_API_KEY=your-key"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let code, let body):
            return "API error \(code): \(body.prefix(200))"
        }
    }
}
