import Foundation

/// Document / Artifact Memory (DM)
/// Files, specs, meeting notes, code excerpts
/// Search uses term-frequency scoring for relevance ranking
struct DocumentChunk: Codable, Identifiable {
    let id: UUID
    let source: String
    let content: String
    let metadata: [String: String]
    let addedAt: Date

    init(id: UUID = UUID(), source: String, content: String,
         metadata: [String: String] = [:], addedAt: Date = Date()) {
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

    /// Term-frequency ranked search — returns chunks sorted by how many query terms they contain
    func search(query: String, limit: Int = 5) -> [DocumentChunk] {
        let terms = query.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }

        guard !terms.isEmpty else { return Array(chunks.prefix(limit)) }

        let scored = chunks.compactMap { chunk -> (DocumentChunk, Int)? in
            let text = (chunk.content + " " + chunk.source).lowercased()
            let score = terms.reduce(0) { acc, term in
                // Count occurrences of each term
                var count = 0
                var searchRange = text.startIndex..<text.endIndex
                while let r = text.range(of: term, range: searchRange) {
                    count += 1
                    searchRange = r.upperBound..<text.endIndex
                }
                return acc + count
            }
            return score > 0 ? (chunk, score) : nil
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }

    func formatted(limit: Int = 3) -> String {
        chunks.prefix(limit).map { chunk in
            "[\(chunk.source)] \(chunk.content.prefix(200))\(chunk.content.count > 200 ? "..." : "")"
        }.joined(separator: "\n\n")
    }
}
