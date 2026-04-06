"""HTTP helpers built on urllib."""

from __future__ import annotations

import json
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from ..errors import ApiError, DownloadError, SearchError

DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36"
)


def fetch_text(url: str, timeout_seconds: float, headers: dict[str, str] | None = None) -> str:
    request_headers = {"User-Agent": DEFAULT_USER_AGENT}
    if headers:
        request_headers.update(headers)
    request = Request(url, headers=request_headers)
    try:
        with urlopen(request, timeout=timeout_seconds) as response:
            charset = response.headers.get_content_charset() or "utf-8"
            return response.read().decode(charset, "replace")
    except HTTPError as exc:
        raise SearchError(f"HTTP {exc.code} while requesting {url}") from exc
    except URLError as exc:
        raise SearchError(f"Failed to reach {url}: {exc.reason}") from exc


def fetch_json(url: str, timeout_seconds: float) -> dict:
    request = Request(url, headers={"User-Agent": DEFAULT_USER_AGENT})
    try:
        with urlopen(request, timeout=timeout_seconds) as response:
            return json.loads(response.read().decode("utf-8", "replace"))
    except HTTPError as exc:
        raise ApiError(f"HTTP {exc.code} while requesting API URL {url}") from exc
    except URLError as exc:
        raise ApiError(f"Failed to reach API URL {url}: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise ApiError(f"API response was not valid JSON for {url}") from exc


def build_url(base_url: str, path: str, params: dict[str, str] | None = None) -> str:
    url = f"{base_url.rstrip('/')}/{path.lstrip('/')}"
    if params:
        url = f"{url}?{urlencode(params)}"
    return url


def download_binary(url: str, timeout_seconds: float) -> tuple[bytes, str]:
    request = Request(url, headers={"User-Agent": DEFAULT_USER_AGENT})
    try:
        with urlopen(request, timeout=timeout_seconds) as response:
            content_type = response.headers.get("Content-Type", "")
            return response.read(), content_type
    except HTTPError as exc:
        raise DownloadError(f"HTTP {exc.code} while downloading {url}") from exc
    except URLError as exc:
        raise DownloadError(f"Failed to download {url}: {exc.reason}") from exc

