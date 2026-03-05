import Foundation

/// Unified memory store — persists all memory types to disk
final class MemoryStore {
    private let fileManager = FileManager.default
    private let baseURL: URL
    
    var storagePath: String { baseURL.path }
    
    var workingMemory: WorkingMemory
    var episodicMemory: EpisodicMemory
    var semanticMemory: SemanticMemory
    var documentMemory: DocumentMemory
    var longSummaryThread: LongSummaryThread
    
    init(baseURL: URL? = nil) {
        let url = baseURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CLOK", isDirectory: true)
        self.baseURL = url
        
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        
        self.workingMemory = Self.load(WorkingMemory.self, from: url.appendingPathComponent("wm.json")) ?? WorkingMemory()
        self.episodicMemory = Self.load(EpisodicMemory.self, from: url.appendingPathComponent("em.json")) ?? EpisodicMemory()
        self.semanticMemory = Self.load(SemanticMemory.self, from: url.appendingPathComponent("sm.json")) ?? SemanticMemory()
        self.documentMemory = Self.load(DocumentMemory.self, from: url.appendingPathComponent("dm.json")) ?? DocumentMemory()
        self.longSummaryThread = Self.load(LongSummaryThread.self, from: url.appendingPathComponent("lst.json")) ?? LongSummaryThread()
    }
    
    private static func load<T: Codable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    
    private func save<T: Codable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url)
    }
    
    func persist() {
        save(workingMemory, to: baseURL.appendingPathComponent("wm.json"))
        save(episodicMemory, to: baseURL.appendingPathComponent("em.json"))
        save(semanticMemory, to: baseURL.appendingPathComponent("sm.json"))
        save(documentMemory, to: baseURL.appendingPathComponent("dm.json"))
        save(longSummaryThread, to: baseURL.appendingPathComponent("lst.json"))
    }
    
    /// Reset all memory to empty state
    func reset() {
        workingMemory = WorkingMemory()
        episodicMemory = EpisodicMemory()
        semanticMemory = SemanticMemory()
        documentMemory = DocumentMemory()
        longSummaryThread = LongSummaryThread()
        persist()
    }
    
    /// Build context string for Claude from all relevant memories
    func buildContextForClaude(userQuery: String, includeLST: Bool = true) -> String {
        var parts: [String] = []
        
        parts.append("## Working Memory (current context)")
        parts.append(workingMemory.formatted())
        parts.append("")
        
        parts.append("## Recent Episodic Memory (what happened)")
        parts.append(episodicMemory.formatted(limit: 5))
        parts.append("")
        
        parts.append("## Semantic Memory (known facts & preferences)")
        parts.append(semanticMemory.formatted(limit: 15))
        parts.append("")
        
        let relevantDocs = documentMemory.search(query: userQuery)
        if !relevantDocs.isEmpty {
            parts.append("## Relevant Documents")
            for chunk in relevantDocs {
                parts.append("[\(chunk.source)] \(chunk.content.prefix(300))...")
            }
            parts.append("")
        }
        
        if includeLST && !longSummaryThread.summary.isEmpty {
            parts.append("## Long Summary Thread (project/relationship overview)")
            parts.append(longSummaryThread.formatted())
            parts.append("")
        }
        
        return parts.joined(separator: "\n")
    }
}
