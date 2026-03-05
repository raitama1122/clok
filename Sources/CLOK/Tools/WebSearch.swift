import Foundation

/// Web search tool — Serper (Google) when API key set, else DuckDuckGo Instant Answer
enum WebSearch {
    
    static func search(_ input: [String: Any]) -> String {
        let query = input["query"] as? String ?? ""
        let maxResults = input["max_results"] as? Int ?? 5
        
        guard !query.isEmpty else { return "Error: query is required" }
        
        if let serperKey = Config.serperApiKey, !serperKey.isEmpty {
            return searchSerper(query: query, maxResults: maxResults, apiKey: serperKey)
        }
        return searchDuckDuckGoHTML(query: query, maxResults: maxResults)
    }
    
    // MARK: - Serper (Google Search)
    
    private static func searchSerper(query: String, maxResults: Int, apiKey: String) -> String {
        guard let url = URL(string: "https://google.serper.dev/search") else { return "Error: Invalid URL" }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["q": query, "num": max(1, min(maxResults, 10))])
        
        var result: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard let data = data, error == nil else {
                result = "Error: \(error?.localizedDescription ?? "Request failed")"
                return
            }
            result = parseSerperResponse(data, maxResults: maxResults)
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 15)
        return result ?? "Error: Request timed out"
    }
    
    private static func parseSerperResponse(_ data: Data, maxResults: Int) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let organic = json["organic"] as? [[String: Any]] else {
            return "Error: Invalid response"
        }
        
        var lines: [String] = []
        for (i, item) in organic.prefix(maxResults).enumerated() {
            let title = item["title"] as? String ?? "No title"
            let link = item["link"] as? String ?? ""
            let snippet = item["snippet"] as? String ?? ""
            lines.append("\(i + 1). \(title)")
            if !snippet.isEmpty { lines.append("   \(snippet)") }
            if !link.isEmpty { lines.append("   \(link)") }
            lines.append("")
        }
        return lines.isEmpty ? "No results found" : lines.joined(separator: "\n")
    }
    
    // MARK: - DuckDuckGo HTML (no API key, real web search)
    
    private static func searchDuckDuckGoHTML(query: String, maxResults: Int) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else { return "Error: Invalid URL" }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        var result: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard let data = data, error == nil else {
                result = "Error: \(error?.localizedDescription ?? "Request failed")"
                return
            }
            if let html = String(data: data, encoding: .utf8) {
                result = parseDuckDuckGoHTML(html, maxResults: maxResults)
            } else {
                result = "Error: Invalid response"
            }
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 15)
        return result ?? "Error: Request timed out"
    }
    
    private static func parseDuckDuckGoHTML(_ html: String, maxResults: Int) -> String {
        var results: [(title: String, snippet: String, url: String)] = []
        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        
        func decode(_ s: String) -> String {
            s.replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Pattern 1: result__a with uddg (main HTML structure)
        let pattern1 = #"<a class="result__a"[^>]*href="[^"]*uddg=([^"&]+)[^"]*"[^>]*>([\s\S]*?)</a>"#
        if let regex = try? NSRegularExpression(pattern: pattern1) {
            let matches = regex.matches(in: html, options: [], range: fullRange)
            for m in matches.prefix(maxResults) {
                let enc = ns.substring(with: m.range(at: 1))
                let rawTitle = ns.substring(with: m.range(at: 2))
                let title = decode(rawTitle.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                if !title.isEmpty {
                    results.append((title: title, snippet: "", url: enc.removingPercentEncoding ?? enc))
                }
            }
        }
        
        // Pattern 2: result__url (alternative structure)
        if results.isEmpty, let regex = try? NSRegularExpression(pattern: #"class="result__url"[^>]*href="[^"]*uddg=([^"&]+)[^"]*"[^>]*>([^<]*)</a>"#) {
            let matches = regex.matches(in: html, options: [], range: fullRange)
            for m in matches.prefix(maxResults) {
                let enc = ns.substring(with: m.range(at: 1))
                let t = decode(ns.substring(with: m.range(at: 2)))
                if !t.isEmpty { results.append((title: t, snippet: "", url: enc.removingPercentEncoding ?? enc)) }
            }
        }
        
        // Pattern 3: direct links in results
        if results.isEmpty, let regex = try? NSRegularExpression(pattern: #"uddg=([^"&]+)[^"]*"[^>]*>([^<]{10,})</a>"#) {
            let matches = regex.matches(in: html, options: [], range: fullRange)
            for m in matches.prefix(maxResults) {
                let enc = ns.substring(with: m.range(at: 1))
                let t = decode(ns.substring(with: m.range(at: 2)))
                if !t.isEmpty && !t.contains("duckduckgo") { results.append((title: t, snippet: "", url: enc.removingPercentEncoding ?? enc)) }
            }
        }
        
        var lines: [String] = []
        for (i, r) in results.enumerated() {
            lines.append("\(i + 1). \(r.title)")
            if !r.snippet.isEmpty { lines.append("   \(r.snippet.prefix(200))\(r.snippet.count > 200 ? "..." : "")") }
            lines.append("   \(r.url)")
            lines.append("")
        }
        return lines.isEmpty ? "No results found" : lines.joined(separator: "\n")
    }
}
