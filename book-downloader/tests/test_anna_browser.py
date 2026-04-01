import sys
import unittest
from pathlib import Path


SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import anna_browser  # noqa: E402


class AnnaBrowserTests(unittest.TestCase):
    def test_special_case_detection(self):
        self.assertTrue(anna_browser.is_todd_sloan_query("Australia Home Buying Guide Todd Sloan"))
        self.assertTrue(anna_browser.is_peter_walsh_query("Let It Go Peter Walsh"))
        self.assertTrue(anna_browser.is_ilona_bray_query("Selling Your House Nolo Ilona Bray"))

    def test_significant_words_drop_stopwords(self):
        self.assertEqual(
            anna_browser.significant_words("Pride and Prejudice by Jane Austen"),
            ["pride", "prejudice", "jane"],
        )

    def test_title_matching_uses_body_text(self):
        self.assertTrue(
            anna_browser.title_matches_query(
                "Pride and Prejudice",
                "Jane Austen public domain classic",
                "Pride and Prejudice Jane Austen",
            )
        )
        self.assertFalse(
            anna_browser.title_matches_query(
                "Completely Different Book",
                "Nothing relevant here",
                "Pride and Prejudice Jane Austen",
            )
        )

    def test_peter_walsh_scoring_prefers_2020_epub(self):
        high_score = anna_browser.score_peter_walsh_candidate(
            "Let It Go - Peter Walsh",
            "2020 EPUB edition",
        )
        low_score = anna_browser.score_peter_walsh_candidate(
            "Let It Go - Peter Walsh",
            "2017 PDF edition",
        )
        self.assertGreater(high_score, low_score)

    def test_ilona_bray_preference(self):
        self.assertTrue(
            anna_browser.is_preferred_ilona_bray_candidate(
                "Selling Your House - Ilona Bray",
                "5th edition 2023",
            )
        )
        self.assertFalse(
            anna_browser.is_preferred_ilona_bray_candidate(
                "Selling Your House - Ilona Bray",
                "2nd edition 2017",
            )
        )

    def test_clean_book_title_removes_site_suffix(self):
        self.assertEqual(
            anna_browser.clean_book_title("Pride and Prejudice - Anna's Archive"),
            "Pride and Prejudice",
        )


if __name__ == "__main__":
    unittest.main()
