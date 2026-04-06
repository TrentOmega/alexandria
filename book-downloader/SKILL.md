---
name: book-downloader
description: Use the API-first Alexandria downloader to search Anna's Archive, validate the best book match, fetch a member fast-download URL with `ANNAS_ARCHIVE_KEY`, and save the resulting file to `~/Downloads/`. Fall back to legacy browser or curl backends only when explicitly requested.
---

# Book Downloader

Use the `book-downloader` wrapper as the default entrypoint.

```bash
./book-downloader "How to Buy a Giant Banana"
./book-downloader "Brain Surgery Made Simple 2020"
```

Pass a single query string. Do not pass the author as a separate positional argument. The helper scripts treat the second argument as an output directory.

## Default Workflow

1. Run `./book-downloader "<query>"`.
2. Let the default `api` backend search Anna's Archive HTML, inspect the top candidates, and validate the best result using generic ranking instead of title-specific hacks.
3. Let the downloader call Anna's Archive member API at `/dyn/api/fast_download.json` using `ANNAS_ARCHIVE_KEY`.
4. Let the downloader save the resulting file directly to `~/Downloads/`.

Use the bundled wrapper instead of reimplementing Anna's Archive search or API access ad hoc. If the API-first path is unavailable, set `ANNAS_DOWNLOADER_BACKEND=playwright` or `ANNAS_DOWNLOADER_BACKEND=curl` to opt into a legacy backend.

## Bundled Resources

- `book-downloader`
  Use as the primary end-to-end wrapper. It defaults to the native Python API-first backend under `src/alexandria_annas/`, loads settings from `.env`, and keeps legacy browser/curl backends available behind explicit `ANNAS_DOWNLOADER_BACKEND` values.
- `src/alexandria_annas/`
  Use as the primary implementation. It performs HTML search, generic ranking, member API fast-download resolution, and direct file download without making Playwright the default path.
- `scripts/anna_browser.py`
  Treat as a legacy browser fallback. It drives headed Chrome through Playwright, follows the real browser flow, and writes failure artifacts under `ANNAS_BROWSER_ARTIFACT_DIR` when automation fails.
- `scripts/legacy_curl_downloader.sh`
  Treat as the legacy shell fallback backend. Use it only when the native API backend is unavailable and the task explicitly calls for the older `curl`-driven path.
- `scripts/smart_finder.sh`
  Treat as the legacy shell finder. It still handles known problematic titles and validation, but it is no longer the default end-to-end path.
- `scripts/download_with_key.sh`
  Use only for legacy authenticated `curl` workflows.
- `scripts/download_book.sh`
  Use as a generic legacy end-to-end fallback if the wrapper is unavailable and a single shell script should perform search plus download.
- `scripts/recent_edition_finder.sh`
  Use when the user explicitly wants the newest available edition.
- `scripts/exact_match_finder.sh`, `scripts/defensive_finder.sh`, `scripts/rigorous_finder.sh`, `scripts/specific_books_finder.sh`
  Use for strict matching on known troublesome queries. Prefer them only after `smart_finder.sh` misses or returns ambiguous results.
- `scripts/basic_finder.sh`, `scripts/simple_book_finder.sh`, `scripts/simple_validated_finder.sh`, `scripts/enhanced_finder.sh`, `scripts/improved_book_finder.sh`, `scripts/intelligent_finder.sh`
  Treat as older fallback strategies for debugging or experimentation, not the default path.
- `scripts/simple_downloader.sh`
  Treat as an older authenticated downloader. Prefer `scripts/download_with_key.sh`.
- `scripts/queue_writer.sh`
  Use only when the task explicitly includes updating the separate Alexandria downloads queue repository.

When running a helper script directly, use:

```bash
./scripts/<name>.sh "<query>" [output_dir]
```

## Query Rules

- Include author and edition information in the single query string when known.
- Prefer exact title plus author for ambiguous books.
- Include a year or format only when the user cares about a specific edition.
- Reject weak matches instead of downloading the wrong book.

## Output and Environment

- `book-downloader` downloads files to `~/Downloads/`.
- Most helper scripts, when run directly, accept `[output_dir]` as the second argument and otherwise default to `$HOME/.claude/downloads/`.
- Place `ANNAS_DOWNLOADER_BACKEND=api` in `<skill-dir>/.env` to use the default native backend.
- Place `ANNAS_SEARCH_BACKEND=html` in `<skill-dir>/.env` to use live HTML search.
- Place `ANNAS_ARCHIVE_BASE_URL=https://annas-archive.li` in `<skill-dir>/.env` to select the active mirror for both search and API requests.
- Place `ANNAS_TIMEOUT_SECONDS=30` in `<skill-dir>/.env` to control request timeouts.
- Place `ANNAS_MAX_CANDIDATES=5` in `<skill-dir>/.env` to control how many detail pages are inspected before choosing the best match.
- Place `ANNAS_ENABLE_BROWSER_FALLBACK=false` in `<skill-dir>/.env` to keep browser fallback disabled by default.
- Place `ANNAS_DOWNLOADER_BACKEND=playwright` in `<skill-dir>/.env` only when you explicitly want the browser backend.
- Place `ANNAS_BROWSER_CHANNEL=chrome` in `<skill-dir>/.env` to target Chrome.
- Place `ANNAS_BROWSER_USER_DATA_DIR=/absolute/path/to/profile-dir` in `<skill-dir>/.env` to reuse a persistent browser profile across runs.
- Place `ANNAS_BROWSER_HEADLESS=false` in `<skill-dir>/.env` to keep the default headed mode.
- Place `ANNAS_BROWSER_TIMEOUT_MS=30000` in `<skill-dir>/.env` to control browser wait timeouts.
- Place `ANNAS_BROWSER_ARTIFACT_DIR=/tmp/book-downloader-artifacts` in `<skill-dir>/.env` to control where screenshots, HTML, and traces are stored on failure.
- Place `ANNAS_ARCHIVE_KEY=...` in `<skill-dir>/.env` to enable authenticated requests.
- Place `ANNAS_ARCHIVE_COOKIE_JAR=/absolute/path/to/anna_cookies.txt` in `<skill-dir>/.env` only when using `ANNAS_DOWNLOADER_BACKEND=curl`. Use a Netscape-format cookie file.
- The wrapper loads these settings automatically before choosing the backend.

## Setup

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/playwright install chrome
```

## URL Pattern

Preserve the MD5 detail-page workflow for search results and use the member API for final downloads:

- Detail page: `https://annas-archive.gl/md5/{hash}`
- Member API: `https://annas-archive.li/dyn/api/fast_download.json?md5={hash}&key=...`

Prefer the member API and direct file download. Use the browser path only as a legacy fallback.

If the site returns a DDoS-Guard or challenge page, fail explicitly instead of treating the HTML as a book file, and inspect the saved artifacts.

## Example

```bash
./book-downloader "Brain Surgery Made Simple Noel Quinn"
```

Expected flow:

1. The native backend searches Anna's Archive and prints a validated `Download link: https://annas-archive.../md5/{hash}` line.
2. The backend calls the member API to obtain a fast-download URL for that hash.
3. `book-downloader` saves the resulting PDF or EPUB in `~/Downloads/`.
