"""Normalize common Roman Urdu shopping queries into ranking-friendly English."""

from __future__ import annotations

import re


ROMAN_URDU_MARKERS = (
    "mujhe", "chahiye", "chahye", "batao", "dikhao", "karo", "wala",
    "wali", "wale", "dusra", "dusre", "doosra", "doosre", "iska", "iske",
    "liye", "andar", "sasta", "sasti", "acha", "achi", "behtar",
    "kaisa", "kesa", "iska", "iske", "yeh", "parhai", "rozana", "hazar",
    "hazaar", "kam", "tak", "zyada", "upar", "ke", "ka", "ki",
    "lac", "lakh", "laac", "lak", "lacs", "lakhs",
)

_PHRASE_REPLACEMENTS = (
    (r"\bsab\s+se\s+(?:acha|achi|behtar|behtareen)\b", "best"),
    (r"\b(?:gaming|game)\s+ke\s+liye\b", "for gaming"),
    (r"\b(?:parhai|padhai|study)\s+ke\s+liye\b", "for study"),
    (r"\b(?:office|coding)\s+ke\s+liye\b", "for office"),
    (r"\b(?:rozana|daily|normal)\s+(?:istemal|istamal|use)\b", "daily use"),
    (r"\bbattery\s+(?:achi|acha|behtar|lambi)\b", "long battery"),
    (r"\bbackup\s+(?:acha|achi|zyada)\b", "long battery backup"),
    (r"\bcamera\s+(?:acha|achi|behtar)\b", "best camera"),
    (r"\bkam\s+budget\b", "low budget"),
    (r"\bvalue\s+(?:for|ka)\s+money\b", "value for money"),
    (r"\baur\s+sast[ai]\b", "cheaper"),
    (r"\b(?:koi\s+)?aur\s+(?:option|model)\b", "another option"),
    (r"\bin\s+mein\s+se\b", "among these"),
    (r"\b(?:is|iss)\s+se\b", "this"),
    (r"\b(?:is|iss)\s+ka\b", "its"),
    (r"\b(?:is|iss)\s+ke\b", "its"),
    (r"\b(?:kaisa|kesa)\s+hai\b", "is it good"),
    (r"\bfarq\s+(?:kya\s+hai|batao)?\b", "difference"),
    (r"\bcompare\s+karo\b", "compare"),
    (r"\bspecs?\s+batao\b", "tell specs"),
)

_TOKEN_REPLACEMENTS = {
    "mobail": "mobile", "mobil": "mobile", "fone": "phone",
    "leptop": "laptop", "labtop": "laptop",
    "chahiye": "want", "chahye": "want", "chaheye": "want",
    "sasta": "cheap", "sasti": "cheap", "saste": "cheap",
    "acha": "good", "achi": "good", "achha": "good",
    "behtar": "better", "behtareen": "best",
    "tez": "powerful", "fast": "fast",
    "parhai": "study", "padhai": "study",
    "pehla": "first", "pehli": "first", "pehle": "first",
    "dusra": "second", "doosra": "second", "dusri": "second",
    "dusre": "second", "doosre": "second",
    "teesra": "third", "tisra": "third",
    "yeh": "this", "ye": "this", "woh": "that",
    "iska": "its", "iske": "its", "unki": "their",
    "batao": "tell", "dikhao": "show", "dikhaye": "show",
    "hazar": "k", "hazaar": "k",
    "laac": "lac", "lacs": "lac", "lak": "lakh", "lakhs": "lakh",
}

_MONEY = r"(?:rs\.?|pkr)?\s*\d[\d,]*(?:\.\d+)?\s*(?:crore|lakhs?|lacs?|laac|lak|million|m|k|hazar|hazaar)?"


def prefers_roman_urdu(text: str) -> bool:
    normalized = re.sub(r"[^a-z0-9]+", " ", (text or "").lower())
    return sum(bool(re.search(rf"\b{re.escape(word)}\b", normalized)) for word in ROMAN_URDU_MARKERS) >= 2


def normalize_user_query(text: str) -> str:
    """Return a conservative English form used only for intent/ranking logic."""
    query = " ".join((text or "").lower().strip().split())
    if not query:
        return ""

    # Roman Urdu usually puts the amount before the comparator.
    query = re.sub(
        rf"(?P<amount>{_MONEY})\s+(?:ke\s+)?(?:andar|tak|se\s+kam)",
        lambda match: f" under {match.group('amount')} ",
        query,
    )
    # Users commonly mix Roman Urdu grammar with the English comparator, for
    # example "2 lac ke under" or "2 laac ka under".
    query = re.sub(
        rf"(?P<amount>{_MONEY})\s+(?:(?:ke|ka|ki)\s+)?(?:under|below|or\s+less)",
        lambda match: f" under {match.group('amount')} ",
        query,
    )
    query = re.sub(
        rf"(?P<amount>{_MONEY})\s+(?:se\s+)?(?:zyada|upar)",
        lambda match: f" above {match.group('amount')} ",
        query,
    )

    for pattern, replacement in _PHRASE_REPLACEMENTS:
        query = re.sub(pattern, replacement, query)
    for source, replacement in _TOKEN_REPLACEMENTS.items():
        query = re.sub(rf"\b{re.escape(source)}\b", replacement, query)

    # Remove conversational filler that adds noise to embeddings.
    query = re.sub(
        r"\b(?:mujhe|mjy|koi|please|plz|zara|mere|liye|ke|ki|ka|ho|hai|hain|wala|wali|wale|recommend|karo)\b",
        " ",
        query,
    )
    return " ".join(query.split())
