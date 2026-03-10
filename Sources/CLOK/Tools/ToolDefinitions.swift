import Foundation

/// Tool definitions for Anthropic API — JSON Schema format
enum ToolDefinitions {
    
    static func toolsJSON() -> Data {
        let json = """
        [
          {
            "name": "file_list",
            "description": "List directory contents. Use to discover files and folders at a path. Supports showing hidden files.",
            "input_schema": {
              "type": "object",
              "properties": {
                "path": {"type": "string", "description": "Directory path (default: current dir)"},
                "show_hidden": {"type": "boolean", "description": "Include hidden files"},
                "max_items": {"type": "integer", "description": "Max items to return (default 50)"}
              }
            }
          },
          {
            "name": "file_search",
            "description": "Search for files by name pattern. Searches recursively. Use * as wildcard.",
            "input_schema": {
              "type": "object",
              "properties": {
                "path": {"type": "string", "description": "Base path to search"},
                "pattern": {"type": "string", "description": "Filename pattern (e.g. *.swift, config)"},
                "max_results": {"type": "integer", "description": "Max results (default 30)"}
              }
            }
          },
          {
            "name": "file_grep",
            "description": "Search file contents for text. Like grep. Searches in txt, md, swift, py, js, ts, json by default.",
            "input_schema": {
              "type": "object",
              "properties": {
                "path": {"type": "string", "description": "File or directory path"},
                "query": {"type": "string", "description": "Text to search for"},
                "max_matches": {"type": "integer", "description": "Max matches (default 20)"},
                "extensions": {"type": "array", "items": {"type": "string"}, "description": "File extensions to search"}
              },
              "required": ["query"]
            }
          },
          {
            "name": "file_mkdir",
            "description": "Create a directory. Can create parent directories.",
            "input_schema": {
              "type": "object",
              "properties": {
                "path": {"type": "string", "description": "Directory path to create"},
                "create_intermediates": {"type": "boolean", "description": "Create parent dirs (default true)"}
              },
              "required": ["path"]
            }
          },
          {
            "name": "file_list_by_date",
            "description": "List directory contents sorted by modification date. Use order=newest or order=oldest.",
            "input_schema": {
              "type": "object",
              "properties": {
                "path": {"type": "string", "description": "Directory path"},
                "order": {"type": "string", "enum": ["newest", "oldest"], "description": "Sort order"},
                "max_items": {"type": "integer", "description": "Max items (default 30)"}
              }
            }
          },
          {
            "name": "file_read",
            "description": "Read file contents. Returns up to max_lines lines starting at start_line. Use start_line to paginate through large files — the response tells you how many lines remain and what start_line to use next.",
            "input_schema": {
              "type": "object",
              "properties": {
                "path": {"type": "string", "description": "File path"},
                "start_line": {"type": "integer", "description": "First line to read, 1-indexed (default 1)"},
                "max_lines": {"type": "integer", "description": "Max lines to return (default 150)"}
              },
              "required": ["path"]
            }
          },
          {
            "name": "file_write",
            "description": "Write content to a file. Creates the file and parent directories if needed. Use append=true to add to existing file.",
            "input_schema": {
              "type": "object",
              "properties": {
                "path": {"type": "string", "description": "File path to write"},
                "content": {"type": "string", "description": "Content to write"},
                "append": {"type": "boolean", "description": "If true, append to file instead of overwrite (default false)"}
              },
              "required": ["path", "content"]
            }
          },
          {
            "name": "file_summarize",
            "description": "Get a quick summary of files/dirs: names and sizes. Use to overview a directory.",
            "input_schema": {
              "type": "object",
              "properties": {
                "path": {"type": "string", "description": "Directory path"},
                "paths": {"type": "array", "items": {"type": "string"}, "description": "Specific file paths"}
              }
            }
          },
          {
            "name": "web_search",
            "description": "Search the web for current information. Use when the user asks about news, facts, events, or anything that requires up-to-date info from the internet.",
            "input_schema": {
              "type": "object",
              "properties": {
                "query": {"type": "string", "description": "Search query"},
                "max_results": {"type": "integer", "description": "Max results to return (default 5)"}
              },
              "required": ["query"]
            }
          }
        ]
        """
        return json.data(using: .utf8)!
    }
}
