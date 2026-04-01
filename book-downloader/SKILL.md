---
name: book-downloader
description: Search Anna's Archive mirror domains (`gl`, `pk`, `gd`) for a requested book, validate the result against the requested title, author, or edition, resolve the `/md5/{hash}` detail page to an actual PDF or EPUB download URL, and save the file to `~/Downloads/`. Use when The Agent needs to find or download a book from Anna's Archive, or when a user asks for a book by title, author, edition, or Anna's Archive link.
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
2. Let it call `scripts/smart_finder.sh` to search Anna's Archive and validate the match.
3. Let the wrapper resolve the returned MD5 detail page into an actual mirror or file URL.
4. Let the wrapper download the file to `~/Downloads/`.

Use the bundled scripts instead of reimplementing Anna's Archive scraping or URL construction ad hoc.

## Bundled Resources

- `book-downloader`
  Use as the primary end-to-end wrapper. It runs `scripts/smart_finder.sh`, resolves the validated MD5 detail page to a real download URL, rejects HTML/challenge pages, and downloads the file to `~/Downloads/`.
- `scripts/smart_finder.sh`
  Use as the default finder. It handles known problematic titles, validates detail pages, and loads `ANNAS_ARCHIVE_KEY` automatically when `.env` is present.
- `scripts/download_with_key.sh`
  Use when authenticated requests are needed and the script should manage the key-backed search and download flow directly.
- `scripts/download_book.sh`
  Use as a generic legacy end-to-end fallback if the wrapper is unavailable and a single script should perform search plus download.
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
- Place `ANNAS_ARCHIVE_KEY=...` in `<skill-dir>/.env` to enable authenticated requests. `scripts/smart_finder.sh`, `scripts/download_with_key.sh`, and `scripts/simple_downloader.sh` load it automatically.

## URL Pattern

Preserve the MD5 detail-page workflow:

- Detail page: `https://annas-archive.gl/md5/{hash}`
- Fast download: `https://annas-archive.gl/fast_download/{hash}/0/0`

Prefer resolving the detail page to a real mirror or file URL. Use the `fast_download` pattern only as a fallback if no direct PDF or EPUB link can be extracted.

Only fall back to a manual MD5 link when direct download resolution fails or a specialized script intentionally returns a reference link instead of downloading.

## Example

```bash
./book-downloader "Brain Surgery Made Simple Noel Quinn"
```

Expected flow:

1. `scripts/smart_finder.sh` prints a validated `Download link: https://annas-archive.../md5/{hash}` line.
2. `book-downloader` resolves that detail page to an actual download URL.
3. `book-downloader` rejects HTML/challenge pages and saves the PDF or EPUB in `~/Downloads/`.
