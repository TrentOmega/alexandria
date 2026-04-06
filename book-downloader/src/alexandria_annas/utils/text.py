"""Text normalization and match scoring."""

from __future__ import annotations

import re

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


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip().lower()


def significant_words(query: str) -> list[str]:
    return [word for word in re.findall(r"[A-Za-z0-9]+", query.lower()) if word not in STOPWORDS]


def extract_year(query: str) -> str:
    match = re.search(r"\b(18|19|20)\d{2}\b", query)
    return match.group(0) if match else ""


def title_case_tokens(value: str) -> list[str]:
    return re.findall(r"[A-Za-z0-9]+", normalize_text(value))


def score_match(query: str, title: str, body_text: str) -> int:
    haystack = normalize_text(f"{title} {body_text}")
    title_norm = normalize_text(title)
    tokens = significant_words(query)
    if not tokens:
        return 0

    score = 0
    overlap = 0
    query_token_set = set(tokens)
    for token in tokens:
        if token in title_norm:
            score += 5
            overlap += 1
        elif token in haystack:
            score += 2
            overlap += 1
        else:
            score -= 4

    year = extract_year(query)
    if year and year in haystack:
        score += 4

    if overlap == len(tokens):
        score += 8
    elif overlap >= max(1, min(3, len(tokens) - 1)):
        score += 2

    if title_norm == normalize_text(query):
        score += 10

    title_tokens = [word for word in title_case_tokens(title) if word not in STOPWORDS]
    extra_title_tokens = [word for word in title_tokens if word not in query_token_set]
    score -= min(len(extra_title_tokens), 8) * 2

    title_core = " ".join(word for word in title_tokens if word in query_token_set)
    query_core = " ".join(tokens[: len(title_tokens)])
    if title_core and title_core == query_core:
        score += 6

    return score


def sanitize_filename(value: str, fallback_stem: str = "book") -> str:
    cleaned = re.sub(r"\s+-\s+Anna[’']s Archive.*$", "", value or "", flags=re.IGNORECASE)
    cleaned = re.sub(r'[<>:"/\\|?*]+', "_", cleaned).strip()
    cleaned = re.sub(r"\s+", " ", cleaned).strip(" .")
    return cleaned[:180] or fallback_stem
