"""Normalize English, Roman Urdu, and Urdu-script shopping queries."""

from __future__ import annotations

import re
from functools import lru_cache


ROMAN_URDU_MARKERS = (
    "mujhe", "chahiye", "chahye", "batao", "dikhao", "karo", "wala",
    "wali", "wale", "dusra", "dusre", "doosra", "doosre", "iska", "iske",
    "liye", "andar", "sasta", "sasti", "acha", "achi", "behtar",
    "kaisa", "kesa", "iska", "iske", "yeh", "parhai", "rozana", "hazar",
    "hazaar", "kam", "tak", "zyada", "upar", "ke", "ka", "ki",
    "lac", "lakh", "laac", "lak", "lacs", "lakhs", "buzurg",
    "boorha", "bohra", "umar", "asan", "aasaan", "call",
)

_URDU_SCRIPT_RE = re.compile(r"[\u0600-\u06ff]")
_URDU_DIGITS = str.maketrans("۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩", "01234567890123456789")

# This deliberately translates intent-bearing shopping vocabulary only.  It is
# deterministic, works without an LLM, and leaves product/brand names intact.
_URDU_PHRASE_REPLACEMENTS = (
    (r"طالب\s*علم", " student "),
    (r"گیمنگ\s*(?:نہیں|نہ)", " no gaming "),
    (r"سوشل\s*میڈیا", " social media "),
    (r"ویڈیو\s*کال(?:نگ)?", " video calls "),
    (r"روزمرہ\s*(?:کے\s*)?(?:استعمال|کام)", " daily use "),
    (r"عام\s*استعمال", " basic use "),
    (r"استعمال\s*میں\s*آسان", " easy to use "),
    (r"عمر\s*رسیدہ", " elderly senior "),
    (r"بڑی\s*سکرین", " large screen "),
    (r"لمبی\s*بیٹری", " long battery "),
    (r"اچھی\s*بیٹری", " good battery "),
    (r"اچھا\s*کیمرہ", " good camera "),
    (r"کے\s*لیے", " for "),
    (r"کے\s*اندر", " under "),
    (r"سے\s*کم", " under "),
    (r"سے\s*زیادہ", " above "),
    (r"کیسا\s*ہے", " is it good "),
    (r"کیسی\s*ہے", " is it good "),
    (r"موازنہ\s*کرو", " compare "),
    (r"پہلے\s*والا", " first "),
    (r"دوسرے\s*والا", " second "),
)

_URDU_TOKEN_REPLACEMENTS = {
    # Urdu spellings/transliterations of catalog brands. Brand names must be
    # normalized before hard constraints so an Urdu request cannot drift to a
    # different manufacturer.
    "\u0634\u0627\u0648\u0645\u06cc": "xiaomi", "\u0634\u06cc\u0627\u0624\u0645\u06cc": "xiaomi", "\u0634\u0627\u0624\u0645\u06cc": "xiaomi",
    "\u0633\u0627\u0645 \u0633\u0646\u06af": "samsung", "\u0633\u0627\u0645\u0633\u0646\u06af": "samsung",
    "\u0627\u06cc\u067e\u0644": "apple", "\u0627\u0648\u067e\u0648": "oppo", "\u0648\u06cc\u0648\u0648": "vivo",
    "\u0631\u06cc\u0626\u0644 \u0645\u06cc": "realme", "\u0631\u06cc\u0644\u0645\u06cc": "realme",
    "\u0627\u0646\u0641\u06cc\u0646\u06a9\u0633": "infinix", "\u0627\u0646\u0641\u0646\u06a9\u0633": "infinix",
    "\u0679\u06cc\u06a9\u0646\u0648": "tecno", "\u0648\u0646 \u067e\u0644\u0633": "oneplus",
    "\u06c1\u0648\u0627\u0648\u06d2": "huawei", "\u0622\u0646\u0631": "honor", "\u0646\u0648\u06a9\u06cc\u0627": "nokia",
    "\u0645\u0648\u0679\u0631\u0648\u0644\u0627": "motorola", "\u06af\u0648\u06af\u0644": "google",
    "\u0688\u06cc\u0644": "dell", "\u0627\u06cc\u0686 \u067e\u06cc": "hp", "\u0644\u06cc\u0646\u0648\u0648\u0648": "lenovo",
    "\u0627\u06cc\u0633\u0631": "acer", "\u0627\u06cc\u0633\u0648\u0633": "asus", "\u0627\u06cc\u0645 \u0627\u06cc\u0633 \u0622\u0626\u06cc": "msi",
    # Written Urdu numbers commonly appear directly before hazaar/lakh.
    "\u0627\u06cc\u06a9": "1", "\u062f\u0648": "2", "\u062a\u06cc\u0646": "3", "\u0686\u0627\u0631": "4", "\u067e\u0627\u0646\u0686": "5",
    "\u0686\u06be": "6", "\u0633\u0627\u062a": "7", "\u0622\u0679\u06be": "8", "\u0646\u0648": "9", "\u062f\u0633": "10",
    "موبائل": "phone", "فون": "phone", "سمارٹ فون": "smartphone",
    "لیپ ٹاپ": "laptop", "لیپٹاپ": "laptop",
    "بزرگ": "elderly senior", "بوڑھا": "elderly senior",
    "بوڑھی": "elderly senior", "سینئر": "senior",
    "آسان": "easy", "سادہ": "simple", "بنیادی": "basic",
    "کال": "calls", "کالنگ": "calling", "واٹس ایپ": "whatsapp",
    "پیغام": "messaging", "میسج": "messaging",
    "بیٹری": "battery", "کیمرہ": "camera", "سکرین": "screen",
    "ڈسپلے": "display", "ریم": "ram", "اسٹوریج": "storage",
    "سٹوریج": "storage", "پروسیسر": "processor", "قیمت": "price",
    "گیمنگ": "gaming", "گیم": "game", "پڑھائی": "study",
    "طالبعلم": "student", "سستا": "cheap", "سستی": "cheap",
    "نہیں": "not", "نہ": "not", "صرف": "only", "کام": "work",
    "بجٹ": "budget", "بہترین": "best", "اچھا": "good", "اچھی": "good",
    "چاہیے": "want", "چاہتا": "want", "چاہتی": "want",
    "دکھاؤ": "show", "بتاؤ": "tell", "دوسرا": "another",
    "دوسری": "another", "موازنہ": "compare", "بہتر": "better",
    "وارنٹی": "warranty", "وزن": "weight", "فنگرپرنٹ": "fingerprint",
    "چارجنگ": "charging", "ریٹنگ": "rating", "رنگ": "color",
    "ہزار": "k", "لاکھ": "lakh", "تک": "under",
}

_PHRASE_REPLACEMENTS = (
    (r"\bmac\s+book\b", "macbook"),
    (r"\b(?:umar|omer)\s+(?:rasida|raseeda|daraz)\b", "senior elderly"),
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
    # Frequent brand transcription/typing variants. Keeping these conservative
    # avoids changing unrelated words while preserving the requested brand.
    "samsun": "samsung", "samsng": "samsung", "samung": "samsung",
    "samsang": "samsung", "sumsung": "samsung", "samusng": "samsung",
    "mobail": "mobile", "mobil": "mobile", "moblie": "mobile",
    "moble": "mobile", "moible": "mobile", "mobilee": "mobile",
    "mobilen": "mobile", "fone": "phone", "phon": "phone",
    "phne": "phone", "phoen": "phone", "phonee": "phone",
    "phonen": "phone", "phome": "phone", "phobe": "phone",
    "smarphone": "smartphone", "smartfone": "smartphone",
    "leptop": "laptop", "labtop": "laptop", "laptopn": "laptop",
    "laptoop": "laptop", "latop": "laptop", "laptp": "laptop",
    "lapotp": "laptop", "laptpo": "laptop", "laptap": "laptop",
    "laptob": "laptop", "lapto": "laptop", "laptopss": "laptops",
    "notebok": "notebook", "notbook": "notebook",
    "mackbook": "macbook", "macbok": "macbook", "mcbook": "macbook",
    "chahiye": "want", "chahye": "want", "chaheye": "want",
    "sasta": "cheap", "sasti": "cheap", "saste": "cheap",
    "acha": "good", "achi": "good", "achha": "good",
    "behtar": "better", "behtareen": "best",
    "asan": "easy", "aasaan": "easy",
    "tez": "powerful", "fast": "fast",
    "parhai": "study", "padhai": "study",
    "pehla": "first", "pehli": "first", "pehle": "first",
    "dusra": "second", "doosra": "second", "dusri": "second",
    "dusre": "second", "doosre": "second",
    "teesra": "third", "tisra": "third",
    "yeh": "this", "ye": "this", "woh": "that",
    "iska": "its", "iske": "its", "unki": "their",
    "batao": "tell", "dikhao": "show", "dikhaye": "show",
    "hazar": "k", "hazaar": "k", "thousand": "k", "thousands": "k",
    "laac": "lac", "lacs": "lac", "lak": "lakh", "lakhs": "lakh",
}

_MONEY = r"(?:rs\.?|pkr)?\s*\d[\d,]*(?:\.\d+)?\s*(?:crore|lakhs?|lacs?|laac|lak|million|m|k|thousands?|hazar|hazaar)?"
_MONEY_WITH_MARKER = (
    r"(?:(?:rs\.?|pkr)\s*\d[\d,]*(?:\.\d+)?"
    r"\s*(?:crore|lakhs?|lacs?|laac|lak|million|m|k|thousands?|hazar|hazaar)?|"
    r"\d[\d,]*(?:\.\d+)?\s*(?:crore|lakhs?|lacs?|laac|lak|million|m|k|thousands?|hazar|hazaar))"
)


def prefers_roman_urdu(text: str) -> bool:
    normalized = re.sub(r"[^a-z0-9]+", " ", (text or "").lower())
    if re.fullmatch(
        r"(?:theek|thik)(?: hai)?|shukriya|acha|achha|sahi(?: hai)?",
        normalized.strip(),
    ):
        return True
    return sum(bool(re.search(rf"\b{re.escape(word)}\b", normalized)) for word in ROMAN_URDU_MARKERS) >= 2


def contains_urdu_script(text: str) -> bool:
    """Return True when the user wrote Urdu/Arabic script."""
    return bool(_URDU_SCRIPT_RE.search(text or ""))


def response_language(text: str) -> str:
    """Return English or Roman Urdu; native Urdu input is answered in Roman Urdu."""
    if contains_urdu_script(text):
        return "roman_urdu"
    if prefers_roman_urdu(text):
        return "roman_urdu"
    return "english"


def _translate_urdu_intent(text: str) -> str:
    query = (text or "").translate(_URDU_DIGITS)
    # Urdu places the amount before the comparator. Reorder it while the Urdu
    # comparator is still present so even small amounts cannot be confused with
    # model numbers such as RTX 3050.
    query = re.sub(
        r"(?P<amount>(?:rs\.?|pkr)?\s*\d[\d,]*(?:\.\d+)?\s*(?:ہزار|لاکھ)?)\s*(?:سے\s*کم|تک|کے\s*اندر)",
        lambda match: f" under {match.group('amount')} ",
        query,
        flags=re.IGNORECASE,
    )
    query = re.sub(
        r"(?P<amount>(?:rs\.?|pkr)?\s*\d[\d,]*(?:\.\d+)?\s*(?:ہزار|لاکھ)?)\s*سے\s*زیادہ",
        lambda match: f" above {match.group('amount')} ",
        query,
        flags=re.IGNORECASE,
    )
    for pattern, replacement in _URDU_PHRASE_REPLACEMENTS:
        query = re.sub(pattern, replacement, query)
    # Longest keys first prevents a shorter token consuming a phrase.
    for source in sorted(_URDU_TOKEN_REPLACEMENTS, key=len, reverse=True):
        query = query.replace(source, f" {_URDU_TOKEN_REPLACEMENTS[source]} ")
    return query


@lru_cache(maxsize=2048)
def normalize_user_query(text: str) -> str:
    """Return a conservative English form used only for intent/ranking logic."""
    query = " ".join(_translate_urdu_intent(text).lower().strip().split())
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
        rf"(?P<amount>{_MONEY})\s+(?:ke|ka|ki)\s+(?:under|below|or\s+less)",
        lambda match: f" under {match.group('amount')} ",
        query,
    )
    query = re.sub(
        rf"(?P<amount>{_MONEY_WITH_MARKER})\s+(?:under|below|or\s+less)",
        lambda match: f" under {match.group('amount')} ",
        query,
    )
    query = re.sub(
        r"(?P<amount>(?:(?:rs\.?|pkr)\s*\d[\d,]*(?:\.\d+)?|\d{5,}(?:\.\d+)?))\s+(?:under|below|or\s+less)",
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

    # Senior-user wording is normalized to one stable intent understood by the
    # rule-based ranker as well as the semantic model.
    query = re.sub(
        r"\b(?:elder(?:ly)?|senior citizen|old(?:er)? person|aged|buzurg|boorh[ai]|bohr[ai])\b",
        " senior elderly ",
        query,
    )

    # Remove conversational filler that adds noise to embeddings.
    query = re.sub(
        r"\b(?:mujhe|mjy|koi|please|plz|zara|mere|liye|ke|ki|ka|ho|hai|hain|wala|wali|wale|recommend|karo)\b",
        " ",
        query,
    )
    return " ".join(query.split())
