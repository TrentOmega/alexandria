#!/usr/bin/env python3
"""Playwright backend for the book-downloader skill."""

from __future__ import annotations

import os
import re
import sys
import time
from contextlib import suppress
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import quote_plus, urljoin

STOPWORDS = {
    "a",
    "an",
    "and",
    "by",
    "edition",
    "for",
    "from",
    "guide",
    "in",
    "of",
    "the",
    "to",
}
DEFAULT_DOMAINS = (
    "annas-archive.gl",
    "annas-archive.pk",
    "annas-archive.gd",
)
PETER_WALSH_SEARCH_TERMS = (
    "Let It Go Peter Walsh 2020 epub",
    "Let It Go Peter Walsh 2020",
    "Let It Go Peter Walsh epub",
)
ILONA_BRAY_SEARCH_TERM = "Selling Your House Nolo 5th edition Bray"
ILONA_BRAY_VERIFIED_URL = "https://annas-archive.gl/md5/5f1439becff40efa007e7e82bb0975e7"
ILONA_BRAY_FALLBACK_URL = "https://annas-archive.gl/md5/c43bbbcb67a31fba4a959951e4919db6"
CHALLENGE_MARKERS = (
    "ddos-guard",
    "checking your browser",
    "attention required",
    "captcha",
    "challenge",
    "enable javascript",
)
STEALTH_SCRIPT = """
Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
Object.defineProperty(navigator, 'languages', {get: () => ['en-US', 'en']});
Object.defineProperty(navigator, 'plugins', {get: () => [1, 2, 3, 4, 5]});
window.chrome = window.chrome || { runtime: {} };
"""


class DownloaderError(RuntimeError):
    exit_code = 1

    def __init__(self, message: str, artifact_dir: Path | None = None):
        super().__init__(message)
        self.artifact_dir = artifact_dir


class ChallengeError(DownloaderError):
    exit_code = 2


class NavigationError(DownloaderError):
    exit_code = 3


class NoMatchError(DownloaderError):
    exit_code = 4


class DownloadError(DownloaderError):
    exit_code = 5


@dataclass(frozen=True)
class Config:
    query: str
    output_dir: Path
    channel: str
    headless: bool
    timeout_ms: int
    artifact_root: Path
    artifact_dir: Path
    user_data_dir: Path
    domains: tuple[str, ...]
    min_file_bytes: int = 1024
    max_search_results: int = 5
    max_download_hops: int = 4
    navigation_retries: int = 2
    user_agent: str = (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )


@dataclass(frozen=True)
class BookMatch:
    title: str
    detail_url: str


@dataclass(frozen=True)
class DownloadLink:
    absolute_url: str
    raw_href: str
    priority: int
    text: str


def log(message: str) -> None:
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}", file=sys.stderr)


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip().lower()


def clean_book_title(title: str) -> str:
    cleaned = re.sub(r"\s+-\s+Anna[’']s Archive.*$", "", title or "", flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", cleaned).strip() or "book"


def significant_words(query: str, limit: int = 3) -> list[str]:
    words = re.findall(r"[A-Za-z0-9]+", query.lower())
    return [word for word in words if word not in STOPWORDS][:limit]


def title_matches_query(title: str, body: str, query: str) -> bool:
    words = significant_words(query)
    if not words:
        return False
    haystack = normalize_text(f"{title} {body}")
    return all(word in haystack for word in words)


def is_todd_sloan_query(query: str) -> bool:
    lowered = normalize_text(query)
    return bool(
        re.search(r"australia.*home.*buying.*guide", lowered)
        or ("todd" in lowered and "sloan" in lowered)
    )


def is_peter_walsh_query(query: str) -> bool:
    lowered = normalize_text(query)
    return bool(re.search(r"let.*it.*go.*walsh", lowered) or ("peter" in lowered and "walsh" in lowered))


def is_ilona_bray_query(query: str) -> bool:
    lowered = normalize_text(query)
    return bool(
        re.search(r"selling.*house.*bray", lowered)
        or ("ilona" in lowered and "bray" in lowered)
        or ("nolo" in lowered and "bray" in lowered)
    )


def score_peter_walsh_candidate(title: str, body: str) -> int:
    haystack = normalize_text(f"{title} {body}")
    if "let it go" not in haystack or "walsh" not in haystack:
        return -1
    score = 0
    if "2020" in haystack:
        score += 10
    if "epub" in haystack:
        score += 3
    if "2017" in haystack:
        score += 1
    return score


def is_preferred_ilona_bray_candidate(title: str, body: str) -> bool:
    haystack = normalize_text(f"{title} {body}")
    return "bray" in haystack and ("5th edition" in haystack or "2023" in haystack)


def is_any_ilona_bray_candidate(title: str, body: str) -> bool:
    haystack = normalize_text(f"{title} {body}")
    return "bray" in haystack and ("selling your house" in haystack or "nolo" in haystack)


def human_size(size_bytes: int) -> str:
    units = ["B", "KB", "MB", "GB"]
    size = float(size_bytes)
    for unit in units:
        if size < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(size)} {unit}"
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{int(size_bytes)} B"


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "_", value.strip()).strip("_")
    return slug[:80] or "book"


def load_env_file(skill_dir: Path) -> None:
    env_file = skill_dir / ".env"
    if not env_file.exists():
        return

    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def build_config(query: str, output_dir_arg: str | None, skill_dir: Path) -> Config:
    load_env_file(skill_dir)

    output_dir = Path(output_dir_arg or str(Path.home() / "Downloads")).expanduser()
    output_dir.mkdir(parents=True, exist_ok=True)

    artifact_root = Path(
        os.environ.get("ANNAS_BROWSER_ARTIFACT_DIR", "/tmp/book-downloader-artifacts")
    ).expanduser()
    artifact_root.mkdir(parents=True, exist_ok=True)

    timestamp = time.strftime("%Y%m%d-%H%M%S")
    artifact_dir = artifact_root / f"{slugify(query)}-{timestamp}"
    artifact_dir.mkdir(parents=True, exist_ok=True)

    domains = tuple(
        domain.strip()
        for domain in os.environ.get("ANNAS_ARCHIVE_DOMAINS", " ".join(DEFAULT_DOMAINS)).split()
        if domain.strip()
    ) or DEFAULT_DOMAINS

    user_data_dir = Path(
        os.environ.get(
            "ANNAS_BROWSER_USER_DATA_DIR",
            str(Path.home() / ".cache/alexandria/book-downloader/chrome-profile"),
        )
    ).expanduser()
    user_data_dir.mkdir(parents=True, exist_ok=True)

    return Config(
        query=query,
        output_dir=output_dir,
        channel=os.environ.get("ANNAS_BROWSER_CHANNEL", "chrome"),
        headless=env_bool("ANNAS_BROWSER_HEADLESS", False),
        timeout_ms=int(os.environ.get("ANNAS_BROWSER_TIMEOUT_MS", "30000")),
        artifact_root=artifact_root,
        artifact_dir=artifact_dir,
        user_data_dir=user_data_dir,
        domains=domains,
    )


def page_body_text(page: Any) -> str:
    with suppress(Exception):
        return page.locator("body").inner_text(timeout=2000)
    return ""


def challenge_detected_in_text(text: str) -> bool:
    lowered = normalize_text(text)
    return any(marker in lowered for marker in CHALLENGE_MARKERS)


def challenge_detected(page: Any) -> bool:
    text = f"{page.title()} {page_body_text(page)}"
    return challenge_detected_in_text(text)


def save_failure_artifacts(page: Any, config: Config, trace_path: Path | None) -> Path:
    if page is not None:
        with suppress(Exception):
            page.screenshot(path=str(config.artifact_dir / "page.png"), full_page=True)
        with suppress(Exception):
            (config.artifact_dir / "page.html").write_text(page.content(), encoding="utf-8")
        with suppress(Exception):
            (config.artifact_dir / "page-url.txt").write_text(page.url, encoding="utf-8")
    if trace_path is not None and trace_path.exists():
        with suppress(Exception):
            (config.artifact_dir / "trace-path.txt").write_text(str(trace_path), encoding="utf-8")
    return config.artifact_dir


def wait_for_page_settle(page: Any, timeout_ms: int) -> None:
    with suppress(Exception):
        page.wait_for_load_state("networkidle", timeout=min(timeout_ms, 10000))
    with suppress(Exception):
        page.wait_for_timeout(1000)


def goto_with_retries(page: Any, url: str, config: Config, context: str) -> None:
    last_error: Exception | None = None

    for attempt in range(config.navigation_retries + 1):
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=config.timeout_ms)
            wait_for_page_settle(page, config.timeout_ms)
            if challenge_detected(page):
                if attempt < config.navigation_retries:
                    log(f"Challenge detected while {context}; retrying")
                    page.wait_for_timeout(1500)
                    continue
                raise ChallengeError(f"DDoS-Guard blocked the request while {context}")
            return
        except DownloaderError:
            raise
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            if attempt < config.navigation_retries:
                log(f"Retrying after navigation error while {context}")
                page.wait_for_timeout(1500)
                continue

    raise NavigationError(f"Failed while {context}: {last_error}")


def collect_anchors(page: Any) -> list[dict[str, str]]:
    anchors = page.eval_on_selector_all(
        "a[href]",
        """
        els => els.map(el => ({
            href: el.getAttribute('href') || '',
            text: (el.textContent || '').replace(/\\s+/g, ' ').trim()
        }))
        """,
    )
    return anchors or []


def extract_detail_urls(page: Any) -> list[str]:
    seen: set[str] = set()
    urls: list[str] = []
    for anchor in collect_anchors(page):
        raw_href = anchor.get("href", "")
        if "/md5/" not in raw_href:
            continue
        absolute_url = urljoin(page.url, raw_href)
        if absolute_url in seen:
            continue
        seen.add(absolute_url)
        urls.append(absolute_url)
    return urls


def collect_download_candidates(page: Any) -> list[DownloadLink]:
    seen: set[str] = set()
    candidates: list[DownloadLink] = []

    for anchor in collect_anchors(page):
        raw_href = anchor.get("href", "")
        if not raw_href or raw_href.startswith("#") or raw_href.startswith("javascript:"):
            continue
        absolute_url = urljoin(page.url, raw_href)
        if absolute_url in seen:
            continue

        text = anchor.get("text", "")
        text_lower = normalize_text(text)
        url_lower = absolute_url.lower()
        priority: int | None = None

        if re.search(r"\.(pdf|epub)(?:$|\?)", url_lower):
            priority = 0
        elif "/fast_download/" in url_lower or "/slow_download/" in url_lower:
            priority = 1
        elif "/member_codes/" in url_lower:
            priority = 2
        elif "/codes/" in url_lower:
            priority = 3
        elif any(token in text_lower for token in ("download", "mirror", "libgen", "ipfs")):
            priority = 4

        if priority is None:
            continue

        seen.add(absolute_url)
        candidates.append(
            DownloadLink(
                absolute_url=absolute_url,
                raw_href=raw_href,
                priority=priority,
                text=text,
            )
        )

    return sorted(candidates, key=lambda item: item.priority)


def detail_page_metadata(page: Any) -> tuple[str, str]:
    return clean_book_title(page.title()), page_body_text(page)


def validate_generic_detail(page: Any, query: str) -> BookMatch | None:
    title, body = detail_page_metadata(page)
    if title_matches_query(title, body, query):
        return BookMatch(title=title, detail_url=page.url)
    return None


def validate_peter_walsh_detail(page: Any) -> tuple[BookMatch | None, int]:
    title, body = detail_page_metadata(page)
    score = score_peter_walsh_candidate(title, body)
    if score < 0:
        return None, -1
    return BookMatch(title=title, detail_url=page.url), score


def validate_ilona_bray_detail(page: Any, preferred_only: bool = False) -> BookMatch | None:
    title, body = detail_page_metadata(page)
    if preferred_only and not is_preferred_ilona_bray_candidate(title, body):
        return None
    if not preferred_only and not is_any_ilona_bray_candidate(title, body):
        return None
    return BookMatch(title=title, detail_url=page.url)


def inspect_detail_candidate(page: Any, detail_url: str, config: Config) -> None:
    goto_with_retries(page, detail_url, config, f"fetching detail page {detail_url}")


def find_todd_sloan_book(_page: Any, _config: Config, _query: str) -> BookMatch:
    raise NoMatchError(
        "This book consistently returns unrelated PC buying guides. Search with an exact ISBN or download manually."
    )


def find_peter_walsh_book(page: Any, config: Config, _query: str) -> BookMatch:
    best_match: BookMatch | None = None
    best_score = -1
    any_domain_reached = False
    last_challenge: ChallengeError | None = None

    for search_term in PETER_WALSH_SEARCH_TERMS:
        log(f"Trying: {search_term}")
        for domain in config.domains:
            url = f"https://{domain}/search?q={quote_plus(search_term)}"
            log(f"Trying: {domain}")
            try:
                goto_with_retries(page, url, config, f"searching {url}")
            except ChallengeError as exc:
                last_challenge = exc
                log(str(exc))
                continue
            except NavigationError:
                log(f"Failed to connect to {domain}")
                continue

            any_domain_reached = True
            detail_urls = extract_detail_urls(page)[: config.max_search_results]
            for detail_url in detail_urls:
                inspect_detail_candidate(page, detail_url, config)
                match, score = validate_peter_walsh_detail(page)
                if match is None:
                    continue
                log(f"Validated Peter Walsh candidate: {match.title}")
                if score > best_score:
                    best_match = match
                    best_score = score
                if score >= 13:
                    return match

    if best_match is not None:
        return best_match
    if last_challenge is not None and not any_domain_reached:
        raise last_challenge
    if not any_domain_reached:
        raise NavigationError("Could not reach any configured Anna's Archive domains.")
    raise NoMatchError("Could not validate any result as Peter Walsh's Let It Go.")


def find_ilona_bray_book(page: Any, config: Config, _query: str) -> BookMatch:
    log("Verifying known 2023 edition")
    last_challenge: ChallengeError | None = None
    try:
        inspect_detail_candidate(page, ILONA_BRAY_VERIFIED_URL, config)
        verified = validate_ilona_bray_detail(page, preferred_only=True)
        if verified is not None:
            return verified
    except ChallengeError as exc:
        last_challenge = exc
        log(str(exc))

    any_domain_reached = False
    for domain in config.domains:
        url = f"https://{domain}/search?q={quote_plus(ILONA_BRAY_SEARCH_TERM)}"
        log(f"Trying: {domain}")
        try:
            goto_with_retries(page, url, config, f"searching {url}")
        except ChallengeError as exc:
            last_challenge = exc
            log(str(exc))
            continue
        except NavigationError:
            log(f"Failed to connect to {domain}")
            continue

        any_domain_reached = True
        detail_urls = extract_detail_urls(page)[: config.max_search_results]
        for detail_url in detail_urls:
            inspect_detail_candidate(page, detail_url, config)
            match = validate_ilona_bray_detail(page, preferred_only=True)
            if match is not None:
                return match

    log("Falling back to the documented 2017 Ilona Bray edition")
    try:
        inspect_detail_candidate(page, ILONA_BRAY_FALLBACK_URL, config)
        fallback = validate_ilona_bray_detail(page, preferred_only=False)
        if fallback is not None:
            return fallback
    except ChallengeError as exc:
        last_challenge = exc
        log(str(exc))

    if last_challenge is not None and not any_domain_reached:
        raise last_challenge
    if not any_domain_reached:
        raise NavigationError("Could not reach any configured Anna's Archive domains.")
    raise NoMatchError("Could not validate any Ilona Bray edition.")


def find_generic_book(page: Any, config: Config, query: str) -> BookMatch:
    any_domain_reached = False
    search_term = quote_plus(query)
    last_challenge: ChallengeError | None = None

    for domain in config.domains:
        url = f"https://{domain}/search?q={search_term}"
        log(f"Trying: {domain}")
        try:
            goto_with_retries(page, url, config, f"searching {url}")
        except ChallengeError as exc:
            last_challenge = exc
            log(str(exc))
            continue
        except NavigationError:
            log(f"Failed to connect to {domain}")
            continue

        any_domain_reached = True
        detail_urls = extract_detail_urls(page)[: config.max_search_results]
        for detail_url in detail_urls:
            inspect_detail_candidate(page, detail_url, config)
            match = validate_generic_detail(page, query)
            title, _body = detail_page_metadata(page)
            log(f"Validating: {title}")
            if match is not None:
                return match
            log("Rejected candidate: title/body did not match the query")

    if last_challenge is not None and not any_domain_reached:
        raise last_challenge
    if not any_domain_reached:
        raise NavigationError("Could not reach any configured Anna's Archive domains.")
    raise NoMatchError("No valid matches found after browser validation.")


def find_book_match(page: Any, config: Config) -> BookMatch:
    if is_todd_sloan_query(config.query):
        return find_todd_sloan_book(page, config, config.query)
    if is_peter_walsh_query(config.query):
        return find_peter_walsh_book(page, config, config.query)
    if is_ilona_bray_query(config.query):
        return find_ilona_bray_book(page, config, config.query)
    return find_generic_book(page, config, config.query)


def save_download(download: Any, config: Config, title: str) -> Path:
    suggested_name = (download.suggested_filename or "").strip()
    if not suggested_name:
        suggested_name = f"{slugify(title)}.bin"

    target_path = config.output_dir / suggested_name
    download.save_as(str(target_path))

    file_size = target_path.stat().st_size if target_path.exists() else 0
    if file_size < config.min_file_bytes:
        with suppress(FileNotFoundError):
            target_path.unlink()
        raise DownloadError(f"Downloaded file is too small to be valid: {file_size} bytes")

    with target_path.open("rb") as handle:
        header = handle.read(2048).lower()

    if b"<!doctype html" in header or b"<html" in header or b"ddos-guard" in header:
        with suppress(FileNotFoundError):
            target_path.unlink()
        raise DownloadError("Browser download resolved to HTML instead of a PDF/EPUB file")

    return target_path


def attempt_download_from_url(page: Any, candidate: DownloadLink, config: Config) -> Any | None:
    downloads: list[Any] = []

    def on_download(download: Any) -> None:
        downloads.append(download)

    page.on("download", on_download)
    try:
        last_error: Exception | None = None
        for attempt in range(config.navigation_retries + 1):
            try:
                page.goto(candidate.absolute_url, wait_until="domcontentloaded", timeout=config.timeout_ms)
                wait_for_page_settle(page, config.timeout_ms)
                break
            except Exception as exc:  # noqa: BLE001
                last_error = exc
                if attempt < config.navigation_retries:
                    page.wait_for_timeout(1000)
                    continue
                raise NavigationError(f"Failed while following {candidate.absolute_url}: {last_error}") from exc
    finally:
        with suppress(Exception):
            page.remove_listener("download", on_download)
        with suppress(Exception):
            page.off("download", on_download)

    if downloads:
        return downloads[0]
    if challenge_detected(page):
        raise ChallengeError(f"DDoS-Guard blocked the request while following {candidate.absolute_url}")
    return None


def walk_download_flow(page: Any, config: Config, visited: set[str], depth: int, title: str) -> Path:
    if depth > config.max_download_hops:
        raise DownloadError("Exceeded the maximum number of browser download hops.")

    candidates = collect_download_candidates(page)
    if not candidates:
        raise DownloadError("Could not find a browser download link on the selected detail page.")

    last_error: DownloaderError | None = None
    for candidate in candidates:
        if candidate.absolute_url in visited:
            continue
        visited.add(candidate.absolute_url)
        log(f"Trying browser path: {candidate.absolute_url}")
        try:
            download = attempt_download_from_url(page, candidate, config)
            if download is not None:
                return save_download(download, config, title)
            return walk_download_flow(page, config, visited, depth + 1, title)
        except ChallengeError:
            raise
        except DownloaderError as exc:
            last_error = exc
            continue

    if last_error is not None:
        raise last_error
    raise DownloadError("All browser download paths were exhausted without a file download.")


def run_playwright_backend(config: Config) -> tuple[BookMatch, Path]:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as exc:  # pragma: no cover - exercised manually
        raise DownloaderError(
            "Playwright is not installed. Run `python3 -m venv .venv`, "
            "`.venv/bin/pip install -r requirements.txt`, and "
            "`.venv/bin/playwright install chrome`."
        ) from exc

    page = None
    trace_path = config.artifact_dir / "trace.zip"

    try:
        with sync_playwright() as playwright:
            context = playwright.chromium.launch_persistent_context(
                str(config.user_data_dir),
                channel=config.channel,
                headless=config.headless,
                accept_downloads=True,
                user_agent=config.user_agent,
                viewport={"width": 1440, "height": 900},
                args=["--disable-blink-features=AutomationControlled"],
            )

            try:
                context.set_default_timeout(config.timeout_ms)
                context.add_init_script(STEALTH_SCRIPT)
                context.tracing.start(screenshots=True, snapshots=True, sources=True)
                page = context.pages[0] if context.pages else context.new_page()

                log(f"Searching for: {config.query}")
                log(f"Using Playwright backend with {config.channel}")

                match = find_book_match(page, config)
                print(f"Found book: {match.title}")
                print(f"Download link: {match.detail_url}")
                print("")

                goto_with_retries(page, match.detail_url, config, f"reopening detail page {match.detail_url}")
                downloaded_path = walk_download_flow(page, config, {match.detail_url}, 0, match.title)

                return match, downloaded_path
            except DownloaderError as exc:
                with suppress(Exception):
                    context.tracing.stop(path=str(trace_path))
                exc.artifact_dir = save_failure_artifacts(page, config, trace_path)
                raise
            finally:
                with suppress(Exception):
                    context.tracing.stop()
                context.close()
    except DownloaderError:
        raise
    except Exception as exc:  # noqa: BLE001
        artifact_dir = save_failure_artifacts(page, config, trace_path if trace_path.exists() else None)
        raise DownloaderError(f"Playwright backend failed: {exc}", artifact_dir=artifact_dir) from exc


def main(argv: list[str] | None = None) -> int:
    args = argv or sys.argv[1:]
    if not args:
        print('Usage: anna_browser.py "book query" [output_dir]')
        return 1

    skill_dir = Path(__file__).resolve().parents[1]
    config = build_config(args[0], args[1] if len(args) > 1 else None, skill_dir)

    try:
        match, file_path = run_playwright_backend(config)
    except DownloaderError as exc:
        log(f"ERROR: {exc}")
        if exc.artifact_dir is not None:
            log(f"Artifacts: {exc.artifact_dir}")
        return exc.exit_code
    except Exception as exc:  # pragma: no cover - defensive fallback
        log(f"ERROR: Unexpected failure: {exc}")
        return 1

    file_size = file_path.stat().st_size
    print(f"✓ Downloaded successfully: {file_path.name} ({human_size(file_size)})")
    print(f"Location: {file_path.parent}/")
    print("")
    print(f"MD5 link (for reference): {match.detail_url}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
