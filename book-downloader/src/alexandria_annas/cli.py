"""CLI entrypoint for the refactored downloader."""

from __future__ import annotations

import sys
from pathlib import Path

from .config import load_config
from .errors import DownloaderError
from .logging import log
from .services.download_service import run_download


def main(argv: list[str] | None = None) -> int:
    args = argv or sys.argv[1:]
    if not args or args[0] in {"-h", "--help"}:
        print('Usage: python -m alexandria_annas.cli "book query" [output_dir]')
        print("")
        print("Default flow: HTML search -> member API fast download -> direct file save")
        return 1

    skill_dir = Path(__file__).resolve().parents[2]

    try:
        config = load_config(args[0], args[1] if len(args) > 1 else None, skill_dir)
        log(f"Searching for: {config.query}")
        result = run_download(config)
    except DownloaderError as exc:
        log(f"ERROR: {exc}")
        return exc.exit_code
    except Exception as exc:  # pragma: no cover
        log(f"ERROR: Unexpected failure: {exc}")
        return 1

    file_size = result.file_path.stat().st_size
    print(f"Found book: {result.match.title}")
    print(f"Download link: {result.match.detail_url}")
    print(f"API downloads left: {result.quota.downloads_left}")
    print("")
    print(f"✓ Downloaded successfully: {result.file_path.name} ({file_size} bytes)")
    print(f"Location: {result.file_path.parent}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
