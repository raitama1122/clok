import Foundation

/// Human-readable status messages for tool execution
enum ToolStatus {
    
    static func describeStart(name: String, input: [String: Any]) -> String {
        switch name {
        case "web_search":
            let q = input["query"] as? String ?? "?"
            return "Searching the web for \"\(q)\"..."
        case "file_list":
            let p = input["path"] as? String ?? "."
            return "Listing files in \(p)..."
        case "file_search":
            let pat = input["pattern"] as? String ?? "*"
            return "Searching for files matching \"\(pat)\"..."
        case "file_grep":
            let q = input["query"] as? String ?? "?"
            return "Searching file contents for \"\(q)\"..."
        case "file_mkdir":
            let p = input["path"] as? String ?? "?"
            return "Creating directory \(p)..."
        case "file_list_by_date":
            let order = input["order"] as? String ?? "newest"
            return "Listing files (sorted by \(order))..."
        case "file_read":
            let p = input["path"] as? String ?? "?"
            return "Reading \(p)..."
        case "file_write":
            let p = input["path"] as? String ?? "?"
            return "Writing to \(p)..."
        case "file_summarize":
            return "Summarizing files..."
        default:
            return "Running \(name)..."
        }
    }
    
    static func describeComplete(name: String, result: String) -> String {
        let lines = result.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let count = lines.count
        if result.hasPrefix("Error:") {
            return "Failed."
        }
        switch name {
        case "web_search":
            let resultCount = result.components(separatedBy: .newlines).filter { $0.range(of: #"^\d+\. "#, options: .regularExpression) != nil }.count
            return resultCount > 0 ? "Got \(resultCount) result(s)." : "No results."
        case "file_list", "file_search", "file_list_by_date":
            return "Found \(count) item(s)."
        case "file_grep":
            return "Found \(count) match(es)."
        case "file_mkdir":
            return "Done."
        case "file_read":
            return "Read \(count) line(s)."
        case "file_write":
            return "Done."
        case "file_summarize":
            return "Done."
        default:
            return "Done."
        }
    }
}
