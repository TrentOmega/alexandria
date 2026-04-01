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
3. Opens the validated MD5 detail page in a real Chrome session through Playwright
4. Follows the browser download flow and saves the file to `~/Downloads/`

**Output**:
- Book downloaded to `~/Downloads/`
- Progress displayed during download
- File size shown on completion

**Important Notes**:
- The skill handles all validation and defensive checks
- Pass a single query string; the wrapper does not accept author as a separate positional argument
- Prefer the `book-downloader` wrapper over calling helper scripts directly
- Default backend: `ANNAS_DOWNLOADER_BACKEND=playwright`
- Install the browser backend with `python3 -m venv .venv`, `.venv/bin/pip install -r requirements.txt`, and `.venv/bin/playwright install chrome`
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
MD5 URL: `https://annas-archive.gl/md5/{hash}`
Fast Download: `https://annas-archive.gl/fast_download/{hash}/0/0`

### Architecture
```
User Request
    ↓
/skill book-downloader "Book Title by Author"
    ↓
Search Anna's Archive → Validate → Open detail page in Chrome → Browser download
    ↓
~/Downloads/
```

## Key Patterns

1. **Primary Backend**: Prefer the Playwright + Chrome backend for all normal downloads
2. **Legacy Fallback**: Use `ANNAS_DOWNLOADER_BACKEND=curl` only when browser automation is unavailable
3. **Validation**: Skill handles title/author matching - don't duplicate
4. **Entry Point**: Prefer `book-downloader`; use `scripts/*.sh` only for targeted debugging or special cases

## When NOT to Use the Skill

- Don't use for non-book downloads
- Don't use if user explicitly wants manual browser download
- Don't bypass the skill to manually construct URLs

## Dependencies

- python3 (required)
- Google Chrome (required)
- Playwright Python package (required for default backend)
- curl and standard Unix tools (required for legacy backend)
- Optional: ANNAS_ARCHIVE_KEY in `book-downloader/.env`
- Optional: ANNAS_ARCHIVE_COOKIE_JAR in `book-downloader/.env` for the legacy backend
- Optional: ANNAS_BROWSER_* settings in `book-downloader/.env` for browser automation tuning

## See Also

- `book-downloader/SKILL.md` - Skill documentation
- `book-downloader/requirements.txt` - Python dependency list
