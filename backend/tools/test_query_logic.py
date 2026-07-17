"""Query logic regression checks for phone/laptop recommendation parsing.

Run:
    python backend/tools/test_query_logic.py
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.api.chat_routes import (  # noqa: E402
    _detect_scope,
    _is_relevant_product_query,
    _normalize_text,
)
from app.recommendation.engine import _parse_query_constraints  # noqa: E402


@dataclass
class Case:
    query: str
    scope: str
    category: str
    budget: Optional[float]


def _eq_budget(actual: Optional[float], expected: Optional[float]) -> bool:
    if actual is None and expected is None:
        return True
    if actual is None or expected is None:
        return False
    return abs(float(actual) - float(expected)) < 1e-6


def run_cases() -> int:
    cases = [
        Case("best phone under 50k", "phones", "phones", 50000.0),
        Case("mobile 20 hazar sa km ka", "phones", "phones", 20000.0),
        Case("mobail under 30k", "phones", "phones", 30000.0),
        Case("fone for gaming under 60k", "phones", "phones", 60000.0),
        Case("best budget phone", "phones", "phones", 30000.0),
        Case("bughet phoens", "phones", "phones", 30000.0),
        Case("best laptop under 150k", "laptops", "laptops", 150000.0),
        Case("laptos for students", "laptops", "laptops", 120000.0),
        Case("labtop for study", "laptops", "laptops", 120000.0),
        Case("student laptop", "laptops", "laptops", 120000.0),
        Case("student laptop under 200k", "laptops", "laptops", 200000.0),
        Case("parhai k liye laptop", "laptops", "laptops", 120000.0),
        Case("gaming laptop with rtx 4060", "laptops", "laptops", None),
    ]

    failures = 0
    for case in cases:
        scope = _detect_scope(case.query)
        parsed = _parse_query_constraints(_normalize_text(case.query))
        category = parsed["query_category"]
        budget = parsed["budget_max"]

        ok = (
            scope == case.scope
            and category == case.category
            and _eq_budget(budget, case.budget)
        )
        if ok:
            print(f"PASS | {case.query}")
            continue

        failures += 1
        print(
            "FAIL | "
            f"{case.query} | "
            f"scope={scope} expected={case.scope} | "
            f"category={category} expected={case.category} | "
            f"budget={budget} expected={case.budget}"
        )

    relevance_cases = [
        ("best phone under 50k", True),
        ("gaming laptop with rtx 4060", True),
        ("best under 50k", True),
        ("camera achi wala mobile", True),
        ("bughet phoens", True),
        ("what is the weather today", False),
        ("write a poem about Pakistan", False),
        ("recommend a movie", False),
        ("what is 2 + 2", False),
        ("", False),
    ]

    for query, expected in relevance_cases:
        actual = _is_relevant_product_query(query)
        if actual == expected:
            print(f"PASS | relevance | {query!r}")
            continue

        failures += 1
        print(
            f"FAIL | relevance | {query!r} | "
            f"actual={actual} expected={expected}"
        )

    total = len(cases) + len(relevance_cases)
    print(f"\nSummary: {total - failures}/{total} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(run_cases())
