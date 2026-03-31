# Agent Guide for Alexandria Project

## Overview

Alexandria is a book download automation system that helps users find and download books from Anna's Archive.

## Available Skills

### book-downloader

**Location**: `/home/user/.claude/skills/book-downloader/`

**Trigger**: Use this skill when the user asks for ANY book download, book search, or mentions wanting a book from Anna's Archive.

**Usage**:
```
/skill book-downloader "Book Title" "Author Name"
```

**What it does**:
1. Searches Anna's Archive (gl, pk, gd domains)
2. Validates the found book matches the query
3. Transforms MD5 URL to fast download URL: `/md5/{hash}` → `/fast_download/{hash}/0/0`
4. Downloads the PDF directly to `~/Downloads/`

**Output**:
- Book downloaded to `~/Downloads/`
- Progress displayed during download
- File size shown on completion

**Important Notes**:
- The skill handles all validation and defensive checks
- No need to use browser extensions (optional/Firefox extension exists but has bugs)
- Direct download is the preferred method

## File Locations

| Location | Purpose |
|----------|---------|
| `~/Downloads/` | Downloaded books |
| `/home/user/.claude/skills/book-downloader/` | Skill code |
| `~/Documents/Projects/alexandria/AGENTS.md` | **This file - agent reference** |
| `~/Documents/Projects/alexandria/CLAUDE.md` | Pointer to AGENTS.md |

## Quick Reference

### Download Command
```
/skill book-downloader "Book Title"
```

### URL Pattern
MD5 URL: `https://annas-archive.gl/md5/{hash}`
Fast Download: `https://annas-archive.gl/fast_download/{hash}/0/0`

### Architecture
```
User Request
    ↓
/skill book-downloader "Book Title"
    ↓
Search Anna's Archive → Validate → Transform URL → Download
    ↓
~/Downloads/
```

## Key Patterns

1. **URL Transformation**: `/md5/{hash}` → `/fast_download/{hash}/0/0`
2. **Direct Download**: Use curl with fast download URL
3. **Validation**: Skill handles title/author matching - don't duplicate

## When NOT to Use the Skill

- Don't use for non-book downloads
- Don't use if user explicitly wants manual browser download
- Don't bypass the skill to manually construct URLs

## Dependencies

- curl (required)
- Standard Unix tools (grep, sed, awk)
- Optional: ANNAS_ARCHIVE_KEY in `book-downloader/.env`

## See Also

- `CLAUDE.md` - High-level project overview
- `book-downloader/SKILL.md` - Skill documentation
- `book-downloader/extension/README.md` - Firefox extension docs