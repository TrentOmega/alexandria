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
1. Searches Anna's Archive using the configured active mirrors
2. Validates the found book matches the query
3. Calls the member fast-download API with `ANNAS_ARCHIVE_KEY`
4. Downloads the resulting file directly to `~/Downloads/`

**Output**:
- Book downloaded to `~/Downloads/`
- Progress displayed during download
- File size shown on completion

**Important Notes**:
- The skill handles all validation and defensive checks
- Pass a single query string; the wrapper does not accept author as a separate positional argument
- Prefer the `book-downloader` wrapper over calling helper scripts directly
- Default backend: `ANNAS_DOWNLOADER_BACKEND=api`
- The native backend uses live HTML search plus the member API for final downloads
- Playwright remains available only as a legacy fallback via `ANNAS_DOWNLOADER_BACKEND=playwright`
- Set `ANNAS_ARCHIVE_COOKIE_JAR` in `book-downloader/.env` only for the legacy `curl` backend
- Treat DDoS-Guard or challenge HTML as a hard failure, not as a valid download

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
MD5 URL: `https://annas-archive.gd/md5/{hash}`
Member API: `https://annas-archive.gd/dyn/api/fast_download.json?md5={hash}&key=...`

### Architecture
```
User Request
    ↓
/skill book-downloader "Book Title by Author"
    ↓
Search Anna's Archive → Validate → Resolve member API fast-download URL → Direct download
    ↓
~/Downloads/
```

## Key Patterns

1. **Primary Backend**: Prefer the native API-first backend for all normal downloads
2. **Legacy Fallbacks**: Use `ANNAS_DOWNLOADER_BACKEND=playwright` or `ANNAS_DOWNLOADER_BACKEND=curl` only when the default path is unsuitable
3. **Validation**: Skill handles title/author matching - don't duplicate
4. **Entry Point**: Prefer `book-downloader`; use `scripts/*.sh` only for targeted debugging or special cases

## When NOT to Use the Skill

- Don't use for non-book downloads
- Don't use if user explicitly wants manual browser download
- Don't bypass the skill to manually construct URLs

## Dependencies

- python3 (required)
- curl and standard Unix tools (required for legacy backend)
- ANNAS_ARCHIVE_KEY in `book-downloader/.env` (required for default backend)
- Optional: Google Chrome and Playwright Python package for the legacy browser backend
- Optional: ANNAS_ARCHIVE_COOKIE_JAR in `book-downloader/.env` for the legacy backend
- Optional: ANNAS_BROWSER_* settings in `book-downloader/.env` for browser automation tuning

## See Also

- `book-downloader/SKILL.md` - Skill documentation
- `book-downloader/requirements.txt` - Python dependency list
