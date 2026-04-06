"""Anna's Archive member API integration."""

from __future__ import annotations

from ..errors import ApiError, DownloadError
from ..models import Config, DownloadInfo, SearchResult
from ..utils.http import build_url, download_binary, fetch_json
from ..utils.text import sanitize_filename


def get_fast_download_info(config: Config, match: SearchResult) -> DownloadInfo:
    last_error: Exception | None = None
    for base_url in config.base_urls:
        try:
            api_url = build_url(
                base_url,
                "/dyn/api/fast_download.json",
                {"md5": match.md5, "key": config.api_key},
            )
            payload = fetch_json(api_url, config.timeout_seconds)
            if "error" in payload:
                raise ApiError(f"Anna's Archive API error: {payload['error']}")

            download_url = payload.get("download_url")
            if not download_url:
                raise ApiError("Anna's Archive API returned no download_url.")

            quota = payload.get("account_fast_download_info", {}) or {}
            return DownloadInfo(
                download_url=download_url,
                downloads_left=int(quota.get("downloads_left", 0) or 0),
                downloads_per_day=int(quota.get("downloads_per_day", 0) or 0),
                downloads_done_today=int(quota.get("downloads_done_today", 0) or 0),
            )
        except ApiError as exc:
            last_error = exc
            continue

    if last_error is not None:
        raise last_error
    raise ApiError("Anna's Archive API request failed for all configured mirrors.")


def _infer_extension(url: str, content_type: str) -> str:
    lower_url = url.lower()
    for ext in ("pdf", "epub", "mobi", "azw3", "djvu", "fb2"):
        if f".{ext}" in lower_url:
            return ext
    content_type = content_type.lower()
    if "epub" in content_type:
        return "epub"
    if "pdf" in content_type:
        return "pdf"
    return "bin"


def download_book(config: Config, match: SearchResult) -> tuple[DownloadInfo, bytes, str]:
    info = get_fast_download_info(config, match)
    content, content_type = download_binary(info.download_url, config.timeout_seconds)
    if len(content) < 1024:
        raise DownloadError(f"Downloaded file is too small to be valid: {len(content)} bytes")

    header = content[:4096].lower()
    if b"<!doctype html" in header or b"<html" in header or b"ddos-guard" in header:
        raise DownloadError("Downloaded response was HTML instead of a book file")

    extension = _infer_extension(info.download_url, content_type)
    return info, content, extension


def save_download(config: Config, match: SearchResult, content: bytes, extension: str) -> str:
    safe_name = sanitize_filename(match.title, fallback_stem=match.md5)
    file_name = f"{safe_name}.{extension}"
    target = config.output_dir / file_name
    target.write_bytes(content)
    return str(target)
