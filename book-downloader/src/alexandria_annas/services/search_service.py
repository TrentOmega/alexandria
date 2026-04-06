"""Search orchestration."""

from __future__ import annotations

from ..errors import SearchError
from ..models import Config, SearchResult
from ..search.html_search import search_html


def find_best_match(config: Config) -> SearchResult:
    if config.search_backend != "html":
        raise SearchError(f"Unsupported search backend: {config.search_backend}")
    return search_html(config)

