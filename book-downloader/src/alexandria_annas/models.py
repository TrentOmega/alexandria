"""Shared data models."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Config:
    query: str
    output_dir: Path
    api_key: str
    base_url: str
    base_urls: tuple[str, ...]
    timeout_seconds: float
    max_candidates: int
    search_backend: str
    browser_fallback_enabled: bool
    browser_channel: str


@dataclass(frozen=True)
class SearchResult:
    md5: str
    detail_url: str
    title: str
    body_text: str
    score: int
    author_hint: str = ""
    year_hint: str = ""
    extension_hint: str = ""


@dataclass(frozen=True)
class DownloadInfo:
    download_url: str
    downloads_left: int = 0
    downloads_per_day: int = 0
    downloads_done_today: int = 0


@dataclass(frozen=True)
class DownloadedBook:
    match: SearchResult
    file_path: Path
    quota: DownloadInfo
    debug: dict[str, str] = field(default_factory=dict)
