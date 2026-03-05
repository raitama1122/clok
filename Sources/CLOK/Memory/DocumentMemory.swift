import Foundation

/// Document / Artifact Memory (DM)
/// Files, specs, meeting notes, code excerpts
/// Stored as chunks + metadata (embeddings can be added later)
struct DocumentChunk: Codable, Identifiable {
    let id: UUID
    let source: String
    let content: String
    let metadata: [String: String]
    let addedAt: Date
    
    init(id: UUID = UUID(), source: String, content: String, metadata: [String: String] = [:], addedAt: Date = Date()) {
        self.id = id
        self.source = source
        self.content = content
        self.metadata = metadata
        self.addedAt = addedAt
    }
}

struct DocumentMemory: Codable {
    var chunks: [DocumentChunk]
    let maxChunks: Int
    
    init(chunks: [DocumentChunk] = [], maxChunks: Int = 1000) {
        self.chunks = chunks
        self.maxChunks = maxChunks
    }
    
    mutating func add(source: String, content: String, metadata: [String: String] = [:]) {
        let chunk = DocumentChunk(source: source, content: content, metadata: metadata)
        chunks.insert(chunk, at: 0)
        if chunks.count > maxChunks {
            chunks = Array(chunks.prefix(maxChunks))
        }
    }
    
    func search(query: String) -> [DocumentChunk] {
        let q = query.lowercased()
        return chunks.filter { chunk in
            chunk.content.lowercased().contains(q) || chunk.source.lowercased().contains(q)
        }.prefix(5).map { $0 }
    }
    
    func formatted(limit: Int = 3) -> String {
        chunks.prefix(limit).map { chunk in
            "[\(chunk.source)] \(chunk.content.prefix(200))\(chunk.content.count > 200 ? "..." : "")"
        }.joined(separator: "\n\n")
    }
}
