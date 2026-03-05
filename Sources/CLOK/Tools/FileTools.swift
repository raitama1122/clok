import Foundation

/// File management tools for CLOK — discover, list, search files on Mac
enum FileTools {
    
    // MARK: - Tool execution
    
    static func execute(name: String, input: [String: Any]) -> String {
        switch name {
        case "file_list":
            return listDirectory(input)
        case "file_search":
            return searchFiles(input)
        case "file_grep":
            return grepFiles(input)
        case "file_mkdir":
            return createDirectory(input)
        case "file_list_by_date":
            return listByDate(input)
        case "file_read":
            return readFile(input)
        case "file_write":
            return writeFile(input)
        case "file_summarize":
            return summarizeFiles(input)
        case "web_search":
            return WebSearch.search(input)
        default:
            return "Unknown tool: \(name)"
        }
    }
    
    // MARK: - file_list (ls)
    
    private static func listDirectory(_ input: [String: Any]) -> String {
        let path = input["path"] as? String ?? "."
        let showHidden = input["show_hidden"] as? Bool ?? false
        let maxItems = input["max_items"] as? Int ?? 50
        
        let url = resolvePath(path)
        guard url != nil else { return "Error: Invalid path '\(path)'" }
        let u = url!
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir), isDir.boolValue else {
            return "Error: Not a directory: \(path)"
        }
        
        do {
            let items = try FileManager.default.contentsOfDirectory(
                at: u,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
                options: showHidden ? [] : .skipsHiddenFiles
            )
            
            var lines: [String] = []
            for item in items.prefix(maxItems) {
                let name = item.lastPathComponent
                let attrs = try? FileManager.default.attributesOfItem(atPath: item.path)
                let isDir = (attrs?[.type] as? FileAttributeType) == .typeDirectory
                let size = attrs?[.size] as? Int ?? 0
                let prefix = isDir ? "d " : "  "
                let sizeStr = isDir ? "<dir>" : ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                lines.append("\(prefix) \(name) (\(sizeStr))")
            }
            
            let total = items.count
            if total > maxItems {
                lines.append("... and \(total - maxItems) more")
            }
            return lines.joined(separator: "\n")
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - file_search (find by name)
    
    private static func searchFiles(_ input: [String: Any]) -> String {
        let path = input["path"] as? String ?? "."
        let pattern = input["pattern"] as? String ?? "*"
        let maxResults = input["max_results"] as? Int ?? 30
        
        let url = resolvePath(path)
        guard let baseURL = url else { return "Error: Invalid path '\(path)'" }
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: baseURL.path, isDirectory: &isDir), isDir.boolValue else {
            return "Error: Not a directory: \(path)"
        }
        
        let enumerator = FileManager.default.enumerator(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey]) { url, error in
            if (error as NSError).code == 257 { return true } // permission denied
            return false
        }
        
        var matches: [String] = []
        let searchPattern = pattern.lowercased().replacingOccurrences(of: "*", with: "")
        
        while let item = enumerator?.nextObject() as? URL, matches.count < maxResults {
            let name = item.lastPathComponent.lowercased()
            if searchPattern.isEmpty || name.contains(searchPattern) {
                let relPath = item.path.replacingOccurrences(of: baseURL.path + "/", with: "")
                matches.append(relPath)
            }
        }
        
        return matches.isEmpty ? "No files found matching '\(pattern)'" : matches.joined(separator: "\n")
    }
    
    // MARK: - file_grep (search content)
    
    private static func grepFiles(_ input: [String: Any]) -> String {
        let path = input["path"] as? String ?? "."
        let query = input["query"] as? String ?? ""
        let maxMatches = input["max_matches"] as? Int ?? 20
        let extAny = input["extensions"]
        let fileExtensions: [String] = (extAny as? [String]) ?? (extAny as? [Any])?.compactMap { $0 as? String } ?? ["txt", "md", "swift", "py", "js", "ts", "json"]
        
        guard !query.isEmpty else { return "Error: query is required" }
        
        let url = resolvePath(path)
        guard let baseURL = url else { return "Error: Invalid path '\(path)'" }
        
        var isDir: ObjCBool = false
        let isDirectory = FileManager.default.fileExists(atPath: baseURL.path, isDirectory: &isDir) && isDir.boolValue
        
        var results: [String] = []
        let q = query.lowercased()
        
        func searchInFile(_ fileURL: URL) {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
            let lines = content.components(separatedBy: .newlines)
            for (i, line) in lines.enumerated() {
                if results.count >= maxMatches { return }
                if line.lowercased().contains(q) {
                    let relPath = fileURL.path.replacingOccurrences(of: baseURL.path + "/", with: "")
                    results.append("\(relPath):\(i + 1): \(line.prefix(120))")
                }
            }
        }
        
        if isDirectory {
            let enumerator = FileManager.default.enumerator(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey])
            while let item = enumerator?.nextObject() as? URL, results.count < maxMatches {
                var isDir: ObjCBool = false
                _ = FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir)
                if !isDir.boolValue {
                    let ext = item.pathExtension.lowercased()
                    if fileExtensions.isEmpty || fileExtensions.contains(ext) {
                        searchInFile(item)
                    }
                }
            }
        } else {
            searchInFile(baseURL)
        }
        
        return results.isEmpty ? "No matches for '\(query)'" : results.joined(separator: "\n")
    }
    
    // MARK: - file_mkdir
    
    private static func createDirectory(_ input: [String: Any]) -> String {
        let path = input["path"] as? String ?? ""
        let createIntermediates = input["create_intermediates"] as? Bool ?? true
        
        guard !path.isEmpty else { return "Error: path is required" }
        
        let url = resolvePath(path)
        guard let targetURL = url else { return "Error: Invalid path '\(path)'" }
        
        do {
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: createIntermediates)
            return "Created directory: \(targetURL.path)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - file_list_by_date
    
    private static func listByDate(_ input: [String: Any]) -> String {
        let path = input["path"] as? String ?? "."
        let order = (input["order"] as? String)?.lowercased() ?? "newest"
        let maxItems = input["max_items"] as? Int ?? 30
        
        let url = resolvePath(path)
        guard let baseURL = url else { return "Error: Invalid path '\(path)'" }
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: baseURL.path, isDirectory: &isDir), isDir.boolValue else {
            return "Error: Not a directory: \(path)"
        }
        
        do {
            let items = try FileManager.default.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: .skipsHiddenFiles
            )
            
            let sorted = items.sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return order == "oldest" ? dateA < dateB : dateA > dateB
            }
            
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm"
            
            let lines = sorted.prefix(maxItems).map { item -> String in
                let date = (try? item.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let prefix = isDir ? "d " : "  "
                return "\(prefix) \(df.string(from: date))  \(item.lastPathComponent)"
            }
            return lines.joined(separator: "\n")
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - file_read
    
    private static func readFile(_ input: [String: Any]) -> String {
        let path = input["path"] as? String ?? ""
        let maxLines = input["max_lines"] as? Int ?? 100
        
        guard !path.isEmpty else { return "Error: path is required" }
        
        let url = resolvePath(path)
        guard let fileURL = url else { return "Error: Invalid path '\(path)'" }
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
            return "Error: Not a file: \(path)"
        }
        
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return "Error: Could not read file (binary or permission denied)"
        }
        
        let lines = content.components(separatedBy: .newlines)
        let display = Array(lines.prefix(maxLines))
        var result = display.joined(separator: "\n")
        if lines.count > maxLines {
            result += "\n... (\(lines.count - maxLines) more lines)"
        }
        return result
    }
    
    // MARK: - file_write
    
    private static func writeFile(_ input: [String: Any]) -> String {
        let path = input["path"] as? String ?? ""
        let content = input["content"] as? String ?? ""
        let append = input["append"] as? Bool ?? false
        
        guard !path.isEmpty else { return "Error: path is required" }
        guard !content.isEmpty else { return "Error: content is required" }
        
        let url = resolvePath(path)
        guard let fileURL = url else { return "Error: Invalid path '\(path)'" }
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
            return "Error: Path is a directory, not a file: \(path)"
        }
        
        do {
            let parent = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parent.path) {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            }
            
            if append {
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                } else {
                    let handle = try FileHandle(forWritingTo: fileURL)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: (content + "\n").data(using: .utf8)!)
                    try handle.close()
                }
            } else {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            return "Wrote \(content.count) chars to \(fileURL.path)"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - file_summarize
    
    private static func summarizeFiles(_ input: [String: Any]) -> String {
        let paths = input["paths"] as? [String] ?? []
        let path = input["path"] as? String ?? "."
        
        var urls: [URL] = []
        if !paths.isEmpty {
            for p in paths {
                if let u = resolvePath(p) { urls.append(u) }
            }
        } else if let u = resolvePath(path) {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: u.path, isDirectory: &isDir), isDir.boolValue {
                urls = (try? FileManager.default.contentsOfDirectory(at: u, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)) ?? []
            } else {
                urls = [u]
            }
        }
        
        var summary: [String] = []
        for url in urls.prefix(10) {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
                let count = (try? FileManager.default.contentsOfDirectory(atPath: url.path).count) ?? 0
                summary.append("\(url.lastPathComponent)/ (\(count) items)")
            } else {
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let size = attrs?[.size] as? Int ?? 0
                summary.append("\(url.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))")
            }
        }
        return summary.isEmpty ? "No files to summarize" : summary.joined(separator: "\n")
    }
    
    // MARK: - Helpers
    
    private static func resolvePath(_ path: String) -> URL? {
        var p = path
        if p.hasPrefix("~") {
            p = (p as NSString).expandingTildeInPath
        }
        if !(p.hasPrefix("/")) {
            p = FileManager.default.currentDirectoryPath + "/" + p
        }
        return URL(fileURLWithPath: (p as NSString).standardizingPath)
    }
    
    static var toolNamesForSettings: [String] {
        ["file_list", "file_search", "file_grep", "file_mkdir", "file_list_by_date", "file_read", "file_write", "file_summarize", "web_search"]
    }
}
