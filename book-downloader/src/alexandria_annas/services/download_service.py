"""End-to-end download orchestration."""

from __future__ import annotations

from pathlib import Path

from ..models import Config, DownloadedBook
from ..providers.annas_api import download_book, save_download
from .search_service import find_best_match


def run_download(config: Config) -> DownloadedBook:
    match = find_best_match(config)
    quota, content, extension = download_book(config, match)
    saved_path = Path(save_download(config, match, content, extension))
    return DownloadedBook(
        match=match,
        file_path=saved_path,
        quota=quota,
        debug={"backend": "native-api", "search_backend": config.search_backend},
    )

