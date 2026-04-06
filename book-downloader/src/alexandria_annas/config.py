"""Configuration loading."""

from __future__ import annotations

import os
from pathlib import Path

from .errors import ConfigError
from .models import Config

DEFAULT_BASE_URLS = (
    "https://annas-archive.gd",
    "https://annas-archive.pk",
    "https://annas-archive.gs",
    "https://annas-archive.vg",
)


def _load_env_file(skill_dir: Path) -> None:
    env_path = skill_dir / ".env"
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def _env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def load_config(query: str, output_dir_arg: str | None, skill_dir: Path) -> Config:
    _load_env_file(skill_dir)

    api_key = os.environ.get("ANNAS_ARCHIVE_KEY", "").strip()
    if not api_key:
        raise ConfigError("ANNAS_ARCHIVE_KEY is required in book-downloader/.env for the default API flow.")

    output_dir = Path(output_dir_arg or str(Path.home() / "Downloads")).expanduser()
    output_dir.mkdir(parents=True, exist_ok=True)

    raw_base_urls = (
        os.environ.get("ANNAS_ARCHIVE_BASE_URLS", "").strip()
        or os.environ.get("ANNAS_ARCHIVE_BASE_URL", "").strip()
    )
    if raw_base_urls:
        base_urls = []
        for raw_item in raw_base_urls.replace(",", " ").split():
            item = raw_item.rstrip("/")
            if not item.startswith("http://") and not item.startswith("https://"):
                item = f"https://{item}"
            base_urls.append(item)
        normalized_base_urls = tuple(base_urls)
    else:
        normalized_base_urls = DEFAULT_BASE_URLS

    base_url = normalized_base_urls[0]

    return Config(
        query=query,
        output_dir=output_dir,
        api_key=api_key,
        base_url=base_url,
        base_urls=normalized_base_urls,
        timeout_seconds=float(os.environ.get("ANNAS_TIMEOUT_SECONDS", "30")),
        max_candidates=int(os.environ.get("ANNAS_MAX_CANDIDATES", "5")),
        search_backend=os.environ.get("ANNAS_SEARCH_BACKEND", "html").strip() or "html",
        browser_fallback_enabled=_env_bool("ANNAS_ENABLE_BROWSER_FALLBACK", False),
        browser_channel=os.environ.get("ANNAS_BROWSER_CHANNEL", "chrome").strip() or "chrome",
    )
