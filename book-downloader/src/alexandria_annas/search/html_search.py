"""Live HTML search against Anna's Archive."""

from __future__ import annotations

import re
from html import unescape

from ..errors import NoMatchError, SearchError
from ..models import Config, SearchResult
from ..utils.http import build_url, fetch_text
from ..utils.text import extract_year, normalize_text, score_match


def _strip_html(html: str) -> str:
    text = re.sub(r"(?is)<script.*?>.*?</script>", " ", html)
    text = re.sub(r"(?is)<style.*?>.*?</style>", " ", text)
    text = re.sub(r"(?is)<[^>]+>", " ", text)
    return normalize_text(unescape(text))


def _extract_md5_paths(html: str) -> list[str]:
    seen: set[str] = set()
    results: list[str] = []
    for raw_path in re.findall(r'href="(/md5/[0-9a-fA-F]{32})"', html):
        path = raw_path.lower()
        if path in seen:
            continue
        seen.add(path)
        results.append(path)
    return results


def _parse_title(detail_html: str) -> str:
    match = re.search(r"(?is)<title>(.*?)</title>", detail_html)
    if not match:
        return "Unknown title"
    title = unescape(match.group(1))
    title = re.sub(r"\s+-\s+Anna[’']s Archive.*$", "", title, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", title).strip()


def search_html(config: Config) -> SearchResult:
    last_error: Exception | None = None
    candidates: list[SearchResult] = []

    for base_url in config.base_urls:
        try:
            search_url = build_url(base_url, "/search", {"q": config.query, "display": "table"})
            search_html = fetch_text(search_url, config.timeout_seconds)
            md5_paths = _extract_md5_paths(search_html)
            if not md5_paths:
                continue

            for path in md5_paths[: config.max_candidates]:
                detail_url = build_url(base_url, path)
                detail_html = fetch_text(detail_url, config.timeout_seconds)
                title = _parse_title(detail_html)
                body_text = _strip_html(detail_html)
                md5 = path.rsplit("/", 1)[-1]
                year_hint = extract_year(body_text)
                score = score_match(config.query, title, body_text)
                candidates.append(
                    SearchResult(
                        md5=md5,
                        detail_url=detail_url,
                        title=title,
                        body_text=body_text,
                        score=score,
                        year_hint=year_hint,
                    )
                )
            if candidates:
                break
        except SearchError as exc:
            last_error = exc
            continue

    if not candidates:
        if last_error is not None:
            raise NoMatchError(f"No search results found for query: {config.query}. Last error: {last_error}")
        raise NoMatchError(f"No search results found for query: {config.query}")

    best = max(candidates, key=lambda item: item.score)
    if best.score < 0:
        raise NoMatchError(f"No acceptable match found for query: {config.query}")
    return best
