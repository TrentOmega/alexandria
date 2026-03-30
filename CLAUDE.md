# Alexandria - Book Download Assistant

## Quick Start

Alexandria is a book download automation system for Anna's Archive.

### Download a Book

```
/skill book-downloader "Book Title"
```

Books are saved to: `~/.claude/downloads/`

### For Claude Code Agents

**See AGENTS.md** for detailed agent instructions.

## Project Structure

```
alexandria/
├── CLAUDE.md              # This file - high-level overview
├── AGENTS.md              # Agent reference guide (essential for Claude Code)
├── book-downloader/
│   ├── SKILL.md           # Skill documentation
│   ├── book-downloader    # Main skill script
│   ├── scripts/           # Helper scripts
│   └── extension/         # Firefox extension (optional)
└── alexandria-downloads/  # GitHub queue repo (for extension)
```

## Key Concepts

- **URL Pattern**: `/md5/{hash}` → `/fast_download/{hash}/0/0`
- **Download Method**: Direct curl download (preferred)
- **Extension**: Optional/Firefox only (has bugs)

## Architecture

```
User Request
    ↓
/skill book-downloader "Book Title"
    ↓
Search Anna's Archive → Validate → Transform URL → Download
    ↓
~/.claude/downloads/
```

## Documentation

| File | Purpose |
|------|---------|
| `AGENTS.md` | **Agent reference** - triggers, patterns, file locations |
| `book-downloader/SKILL.md` | Skill usage and configuration |
| `book-downloader/extension/README.md` | Firefox extension docs |

## Dependencies

- curl
- Standard Unix tools (grep, sed, awk)

## License

Personal use. Respect Anna's Archive terms and copyright laws.