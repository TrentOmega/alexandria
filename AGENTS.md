# Agent Guide for Alexandria Project

## Overview

Alexandria is a book download automation system that helps users find and download books from Anna's Archive.

## Available Skills

### book-downloader

**Location**: `/home/user/Documents/Projects/alexandria/book-downloader/`

**Trigger**: Use this skill when the user asks for ANY book download, book search, or mentions wanting a book from Anna's Archive.

**Usage**:
```
/skill book-downloader "Book Title by Author"
```

**What it does**:
1. Searches Anna's Archive (gl, pk, gd domains)
2. Validates the found book matches the query
3. Resolves the MD5 detail page to an actual PDF or EPUB download URL
4. Downloads the file directly to `~/Downloads/`

**Output**:
- Book downloaded to `~/Downloads/`
- Progress displayed during download
- File size shown on completion

**Important Notes**:
- The skill handles all validation and defensive checks
- Pass a single query string; the wrapper does not accept author as a separate positional argument
- Prefer the `book-downloader` wrapper over calling helper scripts directly

## File Locations

| Location | Purpose |
|----------|---------|
| `~/Downloads/` | Downloaded books |
| `/home/user/Documents/Projects/alexandria/book-downloader/` | Skill source code |
| `/home/user/Documents/Projects/alexandria/book-downloader/scripts/` | Bundled helper scripts |
| `~/Documents/Projects/alexandria/AGENTS.md` | **This file - agent reference** |
| `~/Documents/Projects/alexandria/CLAUDE.md` | Pointer to AGENTS.md |

## Quick Reference

### Download Command
```
/skill book-downloader "Book Title by Author"
```

### URL Pattern
MD5 URL: `https://annas-archive.gl/md5/{hash}`
Fast Download: `https://annas-archive.gl/fast_download/{hash}/0/0`

### Architecture
```
User Request
    ↓
/skill book-downloader "Book Title by Author"
    ↓
Search Anna's Archive → Validate → Resolve detail page → Download
    ↓
~/Downloads/
```

## Key Patterns

1. **Fallback URL Transformation**: `/md5/{hash}` → `/fast_download/{hash}/0/0`
2. **Download Resolution**: Prefer resolving the detail page to an actual PDF/EPUB link; use `fast_download` only as fallback
3. **Validation**: Skill handles title/author matching - don't duplicate
4. **Entry Point**: Prefer `book-downloader`; use `scripts/*.sh` only for targeted debugging or special cases

## When NOT to Use the Skill

- Don't use for non-book downloads
- Don't use if user explicitly wants manual browser download
- Don't bypass the skill to manually construct URLs

## Dependencies

- curl (required)
- Standard Unix tools (grep, sed, awk)
- Optional: ANNAS_ARCHIVE_KEY in `book-downloader/.env`

## See Also

- `book-downloader/SKILL.md` - Skill documentation
- `book-downloader/extension/README.md` - Firefox extension docs
