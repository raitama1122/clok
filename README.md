<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013+-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=flat-square" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
</p>

```
╭──────────────────────────────────────────────────────╮
│   ██████╗██╗      ██████╗ ██╗  ██╗                   │
│  ██╔════╝██║     ██╔═══██╗██║ ██╔╝                   │
│  ██║     ██║     ██║   ██║█████╔╝                    │
│  ██║     ██║     ██║   ██║██╔═██╗                    │
│  ╚██████╗███████╗╚██████╔╝██║  ██╗                   │
│   ╚═════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝                   │
│                                                      │
│   LLM-powered CLI with persistent memory             │
│   Type 'help' for commands · 'quit' to exit          │
╰──────────────────────────────────────────────────────╯
```

# CLOK

**CLOK** is a modern macOS CLI powered by [Claude](https://www.anthropic.com) (Anthropic) with **persistent memory**. Chat with an AI that remembers your context, explores your filesystem, and searches the web—all from your terminal.

## Features

- **Persistent memory** — Working, episodic, semantic, document, and long-summary memory
- **File tools** — List, search, grep, read, write, and explore your files
- **Web search** — DuckDuckGo (default) or Serper/Google with API key
- **LineNoise** — History, emacs-style editing, arrow keys
- **Terminal-native** — No markdown in output, colorful UI, witty personality

## Requirements

- macOS 13+
- Swift 5.9+
- [Anthropic API key](https://console.anthropic.com/)

## Quick Start

```bash
# Clone and build
git clone https://github.com/your-username/CLOK.git
cd CLOK
swift build -c release

# Set your API key
export ANTHROPIC_API_KEY=your-key-here

# Run
.build/release/clok
```

## Installation

### Build from source

```bash
cd CLOK
swift build -c release
```

The binary will be at `.build/release/clok`. Add it to your `PATH` or create an alias:

```bash
alias clok='/path/to/CLOK/.build/release/clok'
```

### Configuration

**API key** (required):

```bash
export ANTHROPIC_API_KEY=your-key-here
```

Or create `~/.clok/config`:

```
ANTHROPIC_API_KEY=your-key-here
```

**Web search** (optional) — DuckDuckGo works by default. For better results, add [Serper](https://serper.dev) (2,500 free/month):

```bash
export SERPER_API_KEY=your-key
```

## Memory System

| Type | Description | Size |
|------|-------------|------|
| **Working Memory (WM)** | Current goal, constraints, user prefs | 5–20 bullets |
| **Episodic Memory (EM)** | Events with date, summary, outcome | Max 500 |
| **Semantic Memory (SM)** | Facts, preferences, skills | Max 200 |
| **Document Memory (DM)** | Files, specs, code excerpts | Chunks + metadata |
| **Long Summary Thread (LST)** | Rolling narrative of project/relationship | Updated when needed |

Data is stored in `~/Library/Application Support/CLOK/`.

## Tools

Claude uses these tools automatically when you chat:

| Tool | Description |
|------|-------------|
| `file_list` | List directory (like `ls`) |
| `file_search` | Search files by name pattern |
| `file_grep` | Search file contents |
| `file_mkdir` | Create directory |
| `file_list_by_date` | List sorted by date |
| `file_read` | Read file contents |
| `file_write` | Write content to file |
| `file_summarize` | Summarize files/dirs |
| `web_search` | Search the web |

## Commands

| Command | Description |
|---------|-------------|
| `<message>` | Chat with Claude (full memory + tools) |
| `wm [bullets]` | View/set Working Memory (use `\|` to separate) |
| `em add <summary>` | Add episodic event |
| `sm add <fact>` | Add semantic fact |
| `dm add <source> <content>` | Add document chunk |
| `lst [text]` | View/set Long Summary Thread |
| `mem` | Show memory summary |
| `setting` | Settings (tools, memory, reset) |
| `clear` | Clear conversation history |
| `help` | Show help |
| `quit` | Exit |

## Examples

```bash
# Set working memory
clok> wm Building Swift app | Prefer concise answers

# Add a fact
clok> sm add User prefers short answers

# Add document context
clok> dm add README.md This project uses Swift and Anthropic Claude API

# Chat (Claude sees all memory + can use file tools)
clok> Help me refactor the API client
clok> What files in this directory mention "memory"?
```

## Project Structure

```
CLOK/
├── Package.swift
├── Sources/CLOK/
│   ├── main.swift
│   ├── CLI.swift           # Main loop, commands
│   ├── ClaudeClient.swift  # Anthropic API
│   ├── Config.swift        # API keys, config
│   ├── Style.swift         # ANSI colors
│   ├── TerminalFormat.swift
│   ├── Memory/            # WM, EM, SM, DM, LST
│   └── Tools/              # File tools, web search
└── Packages/linenoise-swift  # Readline (vendored)
```

## Model

Uses **Claude Sonnet 4.6** by default. You can change it in `ClaudeClient.swift` to `claude-opus-4-6` (most capable) or `claude-haiku-4-5` (fastest).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
