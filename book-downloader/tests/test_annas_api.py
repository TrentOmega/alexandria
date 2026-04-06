import unittest
from unittest.mock import patch

from alexandria_annas.config import load_config
from alexandria_annas.models import SearchResult
from alexandria_annas.providers.annas_api import download_book, get_fast_download_info


class ApiTests(unittest.TestCase):
    def setUp(self):
        self.config = load_config("Example Book", None, __import__("pathlib").Path("book-downloader"))
        self.match = SearchResult(
            md5="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            detail_url="https://annas-archive.li/md5/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            title="Example Book",
            body_text="Example body",
            score=10,
        )

    def test_get_fast_download_info(self):
        payload = {
            "download_url": "https://cdn.example/test.pdf",
            "account_fast_download_info": {
                "downloads_left": 9,
                "downloads_per_day": 10,
                "downloads_done_today": 1,
            },
        }
        with patch("alexandria_annas.providers.annas_api.fetch_json", return_value=payload):
            info = get_fast_download_info(self.config, self.match)
            self.assertEqual(info.download_url, "https://cdn.example/test.pdf")
            self.assertEqual(info.downloads_left, 9)

    def test_download_book(self):
        payload = {
            "download_url": "https://cdn.example/test.epub",
            "account_fast_download_info": {},
        }
        with patch("alexandria_annas.providers.annas_api.fetch_json", return_value=payload):
            with patch(
                "alexandria_annas.providers.annas_api.download_binary",
                return_value=(b"X" * 2048, "application/epub+zip"),
            ):
                info, content, extension = download_book(self.config, self.match)
                self.assertEqual(info.download_url, "https://cdn.example/test.epub")
                self.assertEqual(extension, "epub")
                self.assertEqual(len(content), 2048)


if __name__ == "__main__":
    unittest.main()
