# Alexandria

Alexandria is a book download automation repo focused on Anna's Archive.

The current default path is API-first:

1. Search Anna's Archive HTML on a configured working mirror.
2. Rank and validate likely matches.
3. Resolve a fast-download URL through the member API using `ANNAS_ARCHIVE_KEY`.
4. Download the file directly to `~/Downloads/` or a supplied output directory.

## Entry Point

Use the wrapper:

```bash
cd book-downloader
./book-downloader "Pride and Prejudice Jane Austen"
```

The wrapper remains the stable public interface. Internally it now defaults to the native Python backend under `book-downloader/src/alexandria_annas/`.

## Backends

- `api`: default native backend using HTML search plus member API download
- `playwright`: legacy browser fallback
- `curl`: legacy shell fallback

Select a backend with:

```bash
ANNAS_DOWNLOADER_BACKEND=api ./book-downloader "Book Title by Author"
```

## Environment

Configure `book-downloader/.env` with:

- `ANNAS_ARCHIVE_KEY=...`
- `ANNAS_ARCHIVE_BASE_URLS=https://annas-archive.gd https://annas-archive.pk https://annas-archive.gs https://annas-archive.vg`
- `ANNAS_SEARCH_BACKEND=html`
- `ANNAS_TIMEOUT_SECONDS=30`
- `ANNAS_MAX_CANDIDATES=5`

Optional legacy browser settings:

- `ANNAS_ENABLE_BROWSER_FALLBACK=false`
- `ANNAS_BROWSER_CHANNEL=chrome`
- `ANNAS_BROWSER_USER_DATA_DIR=/absolute/path/to/profile-dir`
- `ANNAS_BROWSER_HEADLESS=false`

## Tests

Run:

```bash
PYTHONPATH=book-downloader/src python3 -m unittest discover -s book-downloader/tests -v
```

## Notes

- HTML-based search is still necessary because Anna's Archive does not expose a public search API.
- The member API is used only for final fast-download resolution.
- Legacy Playwright and curl scripts are still present for migration safety, but they are no longer the default flow.
