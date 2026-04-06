import unittest

from alexandria_annas.utils.text import extract_year, sanitize_filename, score_match, significant_words


class TextUtilsTests(unittest.TestCase):
    def test_significant_words_drop_stopwords(self):
        self.assertEqual(
            significant_words("Pride and Prejudice by Jane Austen"),
            ["pride", "prejudice", "jane", "austen"],
        )

    def test_extract_year(self):
        self.assertEqual(extract_year("Some Book 2023 edition"), "2023")
        self.assertEqual(extract_year("No year here"), "")

    def test_score_match_rewards_overlap(self):
        strong = score_match(
            "Pride and Prejudice Jane Austen",
            "Pride and Prejudice",
            "Jane Austen public domain classic",
        )
        weak = score_match(
            "Pride and Prejudice Jane Austen",
            "Totally Different Book",
            "Unrelated body text",
        )
        self.assertGreater(strong, weak)

    def test_sanitize_filename(self):
        self.assertEqual(
            sanitize_filename("Pride and Prejudice - Anna's Archive"),
            "Pride and Prejudice",
        )


if __name__ == "__main__":
    unittest.main()

