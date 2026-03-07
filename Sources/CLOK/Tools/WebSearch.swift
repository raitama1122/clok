import Foundation

/// Web search tool — Serper (Google) when API key set, else Yahoo Search
enum WebSearch {

    static func search(_ input: [String: Any]) -> String {
        let query = input["query"] as? String ?? ""
        let maxResults = input["max_results"] as? Int ?? 5

        guard !query.isEmpty else { return "Error: query is required" }

        if let serperKey = Config.serperApiKey, !serperKey.isEmpty {
            return searchSerper(query: query, maxResults: maxResults, apiKey: serperKey)
        }
        return searchYahoo(query: query, maxResults: maxResults)
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
    
    // MARK: - Yahoo Search (no API key, real web results)

    private static func searchYahoo(query: String, maxResults: Int) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://search.yahoo.com/search?p=\(encoded)") else { return "Error: Invalid URL" }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        var result: String?
        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard let data = data, error == nil else {
                result = "Error: \(error?.localizedDescription ?? "Request failed")"
                return
            }
            let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            result = html.isEmpty ? "Error: Invalid response" : parseYahooHTML(html, maxResults: maxResults)
        }.resume()

        _ = semaphore.wait(timeout: .now() + 15)
        return result ?? "Error: Request timed out"
    }

    private static func parseYahooHTML(_ html: String, maxResults: Int) -> String {
        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        func decode(_ s: String) -> String {
            s.replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#x27;", with: "'")
                .replacingOccurrences(of: "&ndash;", with: "–")
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Yahoo results: <h3><a href="...RU=ENCODED_URL/...">TITLE</a></h3> ... <p>SNIPPET</p>
        let pattern = #"<h3[^>]*>.*?<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>.*?<p[^>]*>(.*?)</p>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return "Error: Regex failed"
        }

        var seen = Set<String>()
        var results: [(title: String, snippet: String, url: String)] = []

        for m in regex.matches(in: html, range: fullRange) {
            guard results.count < maxResults else { break }
            let rawHref = ns.substring(with: m.range(at: 1))
            let rawTitle = ns.substring(with: m.range(at: 2))
            let rawSnippet = ns.substring(with: m.range(at: 3))

            // Decode the real URL from Yahoo's RU= redirect parameter
            let realURL: String
            if let ruRange = rawHref.range(of: "RU="),
               let endRange = rawHref.range(of: "/", range: ruRange.upperBound..<rawHref.endIndex) {
                let encoded = String(rawHref[ruRange.upperBound..<endRange.lowerBound])
                realURL = encoded.removingPercentEncoding ?? encoded
            } else if rawHref.hasPrefix("http") {
                realURL = rawHref
            } else {
                continue
            }

            guard !realURL.contains("yahoo.com"), !seen.contains(realURL) else { continue }
            seen.insert(realURL)

            let title = decode(rawTitle)
            let snippet = decode(rawSnippet)
            guard !title.isEmpty, !title.hasPrefix("http") else { continue }

            results.append((title: title, snippet: snippet, url: realURL))
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
