"""Error types for the Anna's Archive downloader."""


class DownloaderError(RuntimeError):
    """Base exception for downloader failures."""

    exit_code = 1


class ConfigError(DownloaderError):
    """Configuration is invalid or incomplete."""


class SearchError(DownloaderError):
    """Search workflow failed."""

    exit_code = 2


class NoMatchError(SearchError):
    """No acceptable book match could be found."""

    exit_code = 3


class ApiError(DownloaderError):
    """Member API returned an error."""

    exit_code = 4


class DownloadError(DownloaderError):
    """Downloading the final file failed."""

    exit_code = 5

