---
name: book-downloader
description: Use a Playwright-driven Chrome session to search Anna's Archive mirror domains (`gl`, `pk`, `gd`), validate the requested title, author, or edition, follow the real browser download flow, and save the resulting PDF or EPUB to `~/Downloads/`. Use when The Agent needs to find or download a book from Anna's Archive, or when a user asks for a book by title, author, edition, or Anna's Archive link.
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
2. Let it launch `scripts/anna_browser.py` in a headed Chrome session with a persistent browser profile.
3. Let the browser backend search Anna's Archive, validate the best result, open the detail page, and follow the site download flow in the browser.
4. Let Playwright save the real browser download to `~/Downloads/`.

Use the bundled scripts instead of reimplementing Anna's Archive scraping or URL construction ad hoc. If the browser backend is unavailable, set `ANNAS_DOWNLOADER_BACKEND=curl` to fall back to the legacy shell path.

## Bundled Resources

- `book-downloader`
  Use as the primary end-to-end wrapper. It defaults to `scripts/anna_browser.py`, loads browser settings from `.env`, and keeps the legacy shell downloader available behind `ANNAS_DOWNLOADER_BACKEND=curl`.
- `scripts/anna_browser.py`
  Use as the default backend. It drives headed Chrome through Playwright, searches Anna's Archive in a persistent browser profile, follows the real download flow, rejects challenge pages, and writes failure artifacts under `ANNAS_BROWSER_ARTIFACT_DIR` when automation fails.
- `scripts/legacy_curl_downloader.sh`
  Treat as the legacy fallback backend. Use it only when the browser backend is unavailable or the task explicitly calls for the older `curl`-driven path.
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
- Place `ANNAS_DOWNLOADER_BACKEND=playwright` in `<skill-dir>/.env` to use the browser backend by default.
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

Preserve the MD5 detail-page workflow:

- Detail page: `https://annas-archive.gl/md5/{hash}`
- Fast download: `https://annas-archive.gl/fast_download/{hash}/0/0`

Prefer letting the browser backend follow the real download flow from the detail page. Use the `fast_download` pattern only in the legacy `curl` backend.

If the site returns a DDoS-Guard or challenge page, fail explicitly instead of treating the HTML as a book file, and inspect the saved artifacts.

## Example

```bash
./book-downloader "Brain Surgery Made Simple Noel Quinn"
```

Expected flow:

1. `scripts/anna_browser.py` searches Anna's Archive and prints a validated `Download link: https://annas-archive.../md5/{hash}` line.
2. `book-downloader` reopens that detail page in Chrome and follows the browser download flow.
3. `book-downloader` rejects DDoS-Guard/challenge pages, writes artifacts on failure, and saves the PDF or EPUB in `~/Downloads/`.
