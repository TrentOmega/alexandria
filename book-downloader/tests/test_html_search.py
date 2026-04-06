import unittest
from unittest.mock import patch

from alexandria_annas.config import load_config
from alexandria_annas.search.html_search import search_html


SEARCH_HTML = """
<html><body>
  <a href="/md5/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa">First</a>
  <a href="/md5/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb">Second</a>
</body></html>
"""

DETAIL_GOOD = """
<html>
  <head><title>Pride and Prejudice - Anna's Archive</title></head>
  <body>Jane Austen public domain classic 1813</body>
</html>
"""

DETAIL_BAD = """
<html>
  <head><title>Completely Different Book - Anna's Archive</title></head>
  <body>Nothing relevant</body>
</html>
"""


class HtmlSearchTests(unittest.TestCase):
    def test_html_search_picks_best_candidate(self):
        with patch("alexandria_annas.search.html_search.fetch_text") as fetch_text:
            fetch_text.side_effect = [SEARCH_HTML, DETAIL_BAD, DETAIL_GOOD]
            config = load_config("Pride and Prejudice Jane Austen", None, __import__("pathlib").Path("book-downloader"))
            result = search_html(config)
            self.assertEqual(result.md5, "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
            self.assertIn("Pride and Prejudice", result.title)
            self.assertTrue(result.detail_url.startswith("https://"))


if __name__ == "__main__":
    unittest.main()
