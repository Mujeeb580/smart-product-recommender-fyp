"""Run 3,000+ condition combinations through the FastAPI routes.

The large run uses FastAPI's TestClient with a single real Firestore catalog
snapshot. This preserves routing, validation, ranking, and serialization while
avoiding hundreds of thousands of duplicate Firestore reads. Chat web/LLM
calls are replaced with deterministic local functions during this test.
"""

from __future__ import annotations

import json
import math
import os
import random
import re
import statistics
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

os.environ.setdefault("HF_HOME", str(ROOT / ".cache" / "huggingface"))
os.environ.setdefault("TRANSFORMERS_CACHE", str(ROOT / ".cache" / "huggingface"))

from fastapi.testclient import TestClient  # noqa: E402

import app.api.chat_routes as chat_routes  # noqa: E402
import app.api.product_routes as product_routes  # noqa: E402
from app.main import app  # noqa: E402
from app.recommendation.firestore import fetch_products as real_fetch_products  # noqa: E402


SEED = 20260717
RNG = random.Random(SEED)
REPORT_JSON = ROOT / "tools" / "api_2000_query_report.json"
REPORT_MD = ROOT / "tools" / "api_2000_query_report.md"


PHONE_TERMS = [
    "phone", "mobile", "smartphone", "fone", "mobail", "phoen", "phne",
    "phonee", "moblie", "moible",
]
LAPTOP_TERMS = [
    "laptop", "notebook", "labtop", "leptop", "laptopn", "laptpo",
    "lapotp", "latop", "laptap", "laptob",
]
PHONE_BRANDS = ["Samsung", "Xiaomi", "Infinix", "Tecno", "Realme", "Oppo", "Vivo", "Apple", ""]
LAPTOP_BRANDS = ["HP", "Dell", "Lenovo", "Asus", "Acer", "Apple", "MSI", "Infinix", ""]
INTENTS = [
    "best", "gaming", "camera", "battery", "student", "business",
    "coding", "video editing", "daily use", "performance", "budget", "premium",
]
PHONE_SPECS = [
    "", "8gb ram", "12gb ram 256gb storage", "5000mah battery",
    "amoled display", "fast charging", "snapdragon", "good selfie camera",
]
LAPTOP_SPECS = [
    "", "8gb ram 512gb ssd", "16gb ram", "core i5", "core i7",
    "rtx 3050", "rtx 4060", "long battery",
]
BUDGETS = [15000, 20000, 30000, 50000, 75000, 100000, 120000, 150000, 200000, 250000, 300000, 400000]
BUDGET_PATTERNS: list[tuple[str, Callable[[int], str]]] = [
    ("under", lambda value: f"under {value}"),
    ("below_k", lambda value: f"below {value // 1000}k"),
    ("up_to", lambda value: f"up to Rs {value:,}"),
    ("within", lambda value: f"within PKR {value}"),
    ("less_than", lambda value: f"less than {value}"),
    ("roman_urdu", lambda value: f"{value // 1000} hazar se kam"),
    ("max", lambda value: f"maximum budget {value}"),
    ("upto", lambda value: f"upto {value // 1000}k"),
]
MODIFIERS = [
    "", "please recommend", "mujhe chahiye", "Pakistan price",
    "value for money", "latest", "reliable", "not too expensive",
]

BASIC_LAPTOP_QUERIES = [
    "for work and study", "for office work", "for a student",
    "for online classes", "for assignments and notes",
    "for browsing documents and email", "for meetings and video calls",
    "for spreadsheets and presentations", "for basic coding and research",
    "for programming and university", "for business use", "for typing",
    "for daily use", "for general use", "for college classes",
]
BASIC_PHONE_QUERIES = [
    "for daily use", "for calls and whatsapp", "for a student",
    "for work and study", "for social media", "for online classes",
    "for assignments and notes", "for email and browsing",
    "for youtube and netflix", "for video calls and meetings",
    "for business and navigation", "for instagram and tiktok",
    "for messaging", "for general use", "for university",
]
RELATED_MODIFIERS = ["", "please show", "recommend", "mujhe chahiye"]


def price_number(value: Any) -> float:
    raw = str(value or "").lower().replace("rs", "").replace("pkr", "").replace(",", "").strip()
    try:
        return float(raw)
    except ValueError:
        return math.inf


def category_of(product: dict[str, Any]) -> str:
    text = " ".join(str(product.get(key, "")) for key in ("category", "collection", "name")).lower()
    if any(word in text for word in ("phone", "mobile", "smartphone", "iphone")):
        return "phones"
    if any(word in text for word in ("laptop", "notebook", "macbook")):
        return "laptops"
    return "unknown"


def load_catalog_snapshot() -> dict[str, list[dict[str, Any]]]:
    print("Loading one real Firestore snapshot...")
    snapshot = {
        "phones": real_fetch_products("phones"),
        "laptops": real_fetch_products("laptops"),
        "products": real_fetch_products("products"),
    }
    print("Catalog snapshot:", {key: len(value) for key, value in snapshot.items()})
    return snapshot


def install_test_isolation(snapshot: dict[str, list[dict[str, Any]]]) -> None:
    def cached_fetch(collection_name: str | None = None, limit: int = 300) -> list[dict[str, Any]]:
        key = (collection_name or "products").lower().strip()
        if key in ("phone", "phones"):
            items = snapshot["phones"]
        elif key in ("laptop", "laptops"):
            items = snapshot["laptops"]
        else:
            items = snapshot.get(key, snapshot["products"])
        selected = items if limit <= 0 else items[:limit]
        return [item.copy() for item in selected]

    product_routes.fetch_products = cached_fetch
    chat_routes.fetch_products = cached_fetch
    chat_routes.build_verification_context = lambda query, products: {
        "query": query,
        "checked_count": 0,
        "verified_count": 0,
        "items": [],
        "summary": "disabled during deterministic API test",
    }
    chat_routes.generate_explanation = lambda user_query, products, **kwargs: (
        f"Deterministic recommendation reply with {len(products)} products."
    )


def unique_query_cases(scope: str, count: int) -> list[dict[str, Any]]:
    terms = PHONE_TERMS if scope == "phones" else LAPTOP_TERMS
    brands = PHONE_BRANDS if scope == "phones" else LAPTOP_BRANDS
    specs = PHONE_SPECS if scope == "phones" else LAPTOP_SPECS
    seen: set[str] = set()
    cases: list[dict[str, Any]] = []
    while len(cases) < count:
        budget = RNG.choice(BUDGETS)
        pattern_name, pattern = RNG.choice(BUDGET_PATTERNS)
        query = " ".join(
            part for part in (
                RNG.choice(MODIFIERS),
                RNG.choice(INTENTS),
                RNG.choice(brands),
                RNG.choice(terms),
                RNG.choice(specs),
                pattern(budget),
            ) if part
        )
        query = " ".join(query.split())
        if query in seen:
            continue
        seen.add(query)
        cases.append({
            "query": query,
            "collection": scope,
            "expected_scope": scope,
            "budget": budget,
            "budget_pattern": pattern_name,
            "top_n": RNG.choice([1, 3, 5, 7, 10]),
        })
    return cases


def build_recommendation_cases() -> list[dict[str, Any]]:
    cases = unique_query_cases("phones", 900) + unique_query_cases("laptops", 900)
    both_templates = [
        "recommend a phone and laptop under {budget}",
        "compare mobile versus notebook within {budget}",
        "best smartphone and laptop below {budget}k",
        "phone ya laptop {budget} hazar se kam",
    ]
    for index in range(120):
        budget = BUDGETS[index % len(BUDGETS)]
        template = both_templates[index % len(both_templates)]
        shown_budget = (
            budget // 1000
            if "{budget}k" in template or "hazar" in template
            else budget
        )
        cases.append({
            "query": template.format(budget=shown_budget),
            "collection": None,
            "expected_scope": "both",
            "budget": budget,
            "budget_pattern": "both",
            "top_n": 10,
        })
    edge_queries = [
        "", " ", "!!!", "best under 0", "phone under -1", "laptop under 999999999999",
        "📱 best phone under 50k", "لپ ٹاپ under 150k", "फोन under 50000",
        "PHONE UNDER 50K", "phone\nunder\t50000", "phone <script>alert(1)</script>",
        "phone ' OR 1=1 --", "null", "undefined", "NaN budget phone",
        "phone with 128gb ram under 1k", "Apple Samsung Xiaomi phone under 20k",
        "gaming laptop without GPU under 50k", "phone and laptop and tablet and watch",
    ]
    for index in range(80):
        query = edge_queries[index % len(edge_queries)] + (f" case-{index}" if index >= len(edge_queries) else "")
        cases.append({
            "query": query,
            "collection": RNG.choice(["phones", "laptops", None, "invalid_collection"]),
            "expected_scope": None,
            "budget": None,
            "budget_pattern": "edge",
            "top_n": RNG.choice([1, 5, 10, 25]),
        })
    RNG.shuffle(cases)
    return cases


def build_related_query_cases() -> list[dict[str, Any]]:
    """Build typo and paraphrase families for behavior users commonly expect."""
    cases: list[dict[str, Any]] = []
    seen: set[str] = set()

    def add_basic_family(
        scope: str,
        terms: list[str],
        intents: list[str],
        price_ceiling: float,
        target: int,
    ) -> None:
        combinations = [
            " ".join(part for part in (modifier, term, intent) if part)
            for modifier in RELATED_MODIFIERS
            for term in terms
            for intent in intents
        ]
        RNG.shuffle(combinations)
        for query in combinations:
            query = " ".join(query.split())
            if query in seen:
                continue
            seen.add(query)
            cases.append({
                "query": query,
                "collection": None,
                "expected_scope": scope,
                "budget": None,
                "budget_pattern": "related_basic",
                "top_n": 5,
                "expected_nonempty": True,
                "max_reasonable_price": price_ceiling,
                "suite": "related",
            })
            if sum(case.get("expected_scope") == scope and case.get("budget_pattern") == "related_basic" for case in cases) >= target:
                break

    add_basic_family("laptops", LAPTOP_TERMS, BASIC_LAPTOP_QUERIES, 250_000, 300)
    add_basic_family("phones", PHONE_TERMS, BASIC_PHONE_QUERIES, 160_000, 300)

    performance_queries = [
        ("laptops", "gaming laptop with RTX"),
        ("laptops", "powerful laptop for video editing and rendering"),
        ("laptops", "laptop for machine learning and data science"),
        ("laptops", "workstation laptop for AutoCAD and 3D"),
        ("phones", "best gaming phone"),
        ("phones", "flagship performance mobile"),
        ("phones", "best camera smartphone"),
        ("phones", "phone for photography and 4k video"),
    ]
    for index in range(40):
        scope, base = performance_queries[index % len(performance_queries)]
        cases.append({
            "query": f"{RELATED_MODIFIERS[index % len(RELATED_MODIFIERS)]} {base} option {index}".strip(),
            "collection": None,
            "expected_scope": scope,
            "budget": None,
            "budget_pattern": "related_performance",
            "top_n": 5,
            "expected_nonempty": True,
            "suite": "related",
        })

    strict_budget_queries = [
        ("phones", "phone in 30000", 30_000),
        ("phones", "moblie under 50000", 50_000),
        ("phones", "smartphone within PKR 75000", 75_000),
        ("laptops", "laptopn under 150000", 150_000),
        ("laptops", "notebook for 200000", 200_000),
        ("laptops", "labtop within PKR 250000", 250_000),
    ]
    for index in range(60):
        scope, query, budget = strict_budget_queries[index % len(strict_budget_queries)]
        cases.append({
            "query": f"{query} choice {index}",
            "collection": None,
            "expected_scope": scope,
            "budget": budget,
            "budget_pattern": "related_budget",
            "top_n": 5,
            "expected_nonempty": True,
            "suite": "related",
        })

    no_result_queries = [
        ("phones", "phone under 1000"),
        ("phones", "mobile in 1000"),
        ("laptops", "laptop under 10000"),
        ("laptops", "notebook for 20000"),
    ]
    for index in range(20):
        scope, query = no_result_queries[index % len(no_result_queries)]
        cases.append({
            "query": f"{query} impossible {index}",
            "collection": None,
            "expected_scope": scope,
            "budget": int(re.search(r"\d+", query).group()),
            "budget_pattern": "related_no_result",
            "top_n": 5,
            "expect_empty": True,
            "suite": "related",
        })

    RNG.shuffle(cases)
    return cases


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, round((len(ordered) - 1) * fraction))]


def compact_failure(case: dict[str, Any], status: int, reasons: list[str], payload: Any, elapsed_ms: float) -> dict[str, Any]:
    products = payload.get("products", []) if isinstance(payload, dict) else []
    return {
        "query": case.get("query"),
        "collection": case.get("collection"),
        "status": status,
        "reasons": reasons,
        "elapsed_ms": round(elapsed_ms, 1),
        "top_products": [
            {"name": p.get("name"), "price": p.get("price"), "category": p.get("category")}
            for p in products[:3]
        ],
    }


def run_recommendations(client: TestClient, cases: list[dict[str, Any]], failures: list[dict[str, Any]], timings: list[float]) -> Counter:
    counts: Counter = Counter()
    for index, case in enumerate(cases, start=1):
        params = {"query": case["query"], "top_n": case["top_n"]}
        if case["collection"] is not None:
            params["collection"] = case["collection"]
        started = time.perf_counter()
        response = client.get("/products/recommend", params=params)
        elapsed_ms = (time.perf_counter() - started) * 1000
        timings.append(elapsed_ms)
        reasons: list[str] = []
        try:
            payload = response.json()
        except Exception:
            payload = None
        if response.status_code != 200:
            reasons.append(f"status_{response.status_code}")
        elif not isinstance(payload, dict) or not isinstance(payload.get("products"), list):
            reasons.append("invalid_response_shape")
        else:
            products = payload["products"]
            if payload.get("count") != len(products):
                reasons.append("count_mismatch")
            if len(products) > case["top_n"]:
                reasons.append("top_n_exceeded")
            if case.get("expected_nonempty") and not products:
                reasons.append("unexpected_empty")
            if case.get("expect_empty") and products:
                reasons.append("expected_empty")
            expected_scope = case.get("expected_scope")
            if products and expected_scope in ("phones", "laptops"):
                categories = {category_of(product) for product in products}
                if categories - {expected_scope, "unknown"}:
                    reasons.append("scope_mismatch")
            invalid_currency = [
                product for product in products
                if product.get("price") and not re.match(r"^PKR\s+[\d,]+(?:\.\d+)?$", str(product.get("price")))
            ]
            if invalid_currency:
                reasons.append("invalid_currency")
            max_reasonable_price = case.get("max_reasonable_price")
            if products and max_reasonable_price is not None and any(
                price_number(product.get("price")) > max_reasonable_price
                for product in products
            ):
                reasons.append("unreasonable_basic_price")
            budget = case.get("budget")
            if products and budget is not None:
                is_lowest_price_fallback = (
                    products[0].get("fallback_reason")
                    == "no_products_within_budget"
                )
                over_budget = [p for p in products if price_number(p.get("price")) > budget]
                if over_budget and not is_lowest_price_fallback:
                    reasons.append("budget_exceeded")
                if is_lowest_price_fallback and not all(
                    product.get("fallback_reason") == "no_products_within_budget"
                    and product.get("is_over_budget") is True
                    and float(product.get("requested_budget_max") or 0) == float(budget)
                    for product in products
                ):
                    reasons.append("invalid_fallback_metadata")
        if reasons:
            counts["failed"] += 1
            counts.update(reasons)
            if len(failures) < 250:
                failures.append(compact_failure(case, response.status_code, reasons, payload, elapsed_ms))
        else:
            counts["passed"] += 1
        if index % 100 == 0:
            print(f"recommendations {index}/{len(cases)} | pass={counts['passed']} fail={counts['failed']}")
    return counts


def run_chat_cases(client: TestClient, source_cases: list[dict[str, Any]], failures: list[dict[str, Any]], timings: list[float]) -> Counter:
    counts: Counter = Counter()
    greetings = ["hi", "hello", "salam", "aoa", "hey there", "assalam o alaikum"]
    payloads: list[dict[str, Any]] = []
    for index in range(30):
        payloads.append({"message": greetings[index % len(greetings)], "session_id": f"greet-{index}"})
    for index, case in enumerate(source_cases[:130]):
        payloads.append({"message": case["query"], "session_id": f"query-{index}"})
    for index in range(20):
        session = f"follow-{index}"
        payloads.extend([
            {"message": f"best phone under {50000 + index * 1000}", "session_id": session},
            {"message": RNG.choice(["which is better", "tell me more about the first", "show cheaper options"]), "session_id": session},
        ])

    for index, body in enumerate(payloads):
        started = time.perf_counter()
        response = client.post("/chat/send-message", json=body)
        elapsed_ms = (time.perf_counter() - started) * 1000
        timings.append(elapsed_ms)
        reasons: list[str] = []
        try:
            payload = response.json()
        except Exception:
            payload = None
        if response.status_code != 200:
            reasons.append(f"status_{response.status_code}")
        elif not isinstance(payload, dict) or not isinstance(payload.get("reply"), str) or not isinstance(payload.get("products"), list):
            reasons.append("invalid_chat_shape")
        elif re.search(r"₹|₨|\bINR\b|\bRs\.?\s*\d", payload["reply"], re.IGNORECASE):
            reasons.append("invalid_chat_currency")
        elif any(
            product.get("price") and not str(product.get("price")).startswith("PKR ")
            for product in payload["products"]
        ):
            reasons.append("invalid_product_currency")
        if reasons:
            counts["failed"] += 1
            counts.update(reasons)
            if len(failures) < 250:
                failures.append(compact_failure({"query": body.get("message"), "collection": "chat"}, response.status_code, reasons, payload, elapsed_ms))
        else:
            counts["passed"] += 1
        if (index + 1) % 50 == 0:
            print(f"chat {index + 1}/{len(payloads)} | pass={counts['passed']} fail={counts['failed']}")
    return counts


def run_misc_cases(client: TestClient, failures: list[dict[str, Any]], timings: list[float]) -> Counter:
    counts: Counter = Counter()
    cases: list[tuple[str, str, dict[str, Any] | None, set[int], str]] = []
    brands = ["Samsung", "Xiaomi", "HP", "Dell", "NoSuchBrand", ""]
    for index in range(60):
        params = {
            "collection": "phones" if index % 2 == 0 else "laptops",
            "min_price": [0, 20000, 50000, 100000][index % 4],
            "max_price": [50000, 100000, 200000, 500000][index % 4],
            "brand": brands[index % len(brands)],
            "limit": [1, 5, 20, 100][index % 4],
        }
        cases.append(("GET", "/products/filter", params, {200}, "filter"))
    for query in ["Samsung", "gaming", "i7", "RTX", "battery", "camera", "student", "unknown xyz"] * 5:
        cases.append(("GET", "/products/search", {"q": query, "collection": RNG.choice(["phones", "laptops"])}, {200}, "search"))
    for tier in ["Flagship", "Upper Mid", "Mid", "Low", "Unknown"]:
        cases.append(("GET", "/products/phones/performance", {"tier": tier, "limit": 10}, {200}, "phone_performance"))
        cases.append(("GET", "/products/laptops/performance", {"tier": tier, "limit": 10}, {200}, "laptop_performance"))
    for limit in [1, 5, 20, 0, -1]:
        cases.append(("GET", "/products/trending", {"limit": limit}, {200}, "trending"))
    invalid_cases = [
        ("GET", "/products/search", None, {422}, "missing_search_query"),
        ("GET", "/products/recommend", {"top_n": "abc"}, {422}, "invalid_top_n"),
        ("GET", "/products/filter", {"min_price": "abc"}, {422}, "invalid_price"),
        ("POST", "/chat/send-message", {}, {422}, "missing_message"),
        ("POST", "/chat/send-message", {"message": None}, {422}, "null_message"),
        ("GET", "/does-not-exist", None, {404}, "missing_route"),
        ("POST", "/products/recommend", None, {405}, "wrong_method"),
    ]
    cases.extend(invalid_cases * 5)
    while len(cases) < 150:
        cases.append(("GET", "/chat/history", None, {200}, "history"))

    for method, path, payload, expected, label in cases:
        started = time.perf_counter()
        if method == "POST":
            response = client.post(path, json=payload)
        else:
            response = client.get(path, params=payload)
        elapsed_ms = (time.perf_counter() - started) * 1000
        timings.append(elapsed_ms)
        if response.status_code in expected:
            counts["passed"] += 1
        else:
            counts["failed"] += 1
            counts[f"unexpected_{response.status_code}"] += 1
            if len(failures) < 250:
                failures.append({
                    "query": label,
                    "path": path,
                    "status": response.status_code,
                    "reasons": [f"expected_{sorted(expected)}"],
                    "elapsed_ms": round(elapsed_ms, 1),
                })
    return counts


def write_reports(report: dict[str, Any]) -> None:
    REPORT_JSON.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    summary = report["summary"]
    lines = [
        "# 3,000+ Comprehensive API Query Test Report",
        "",
        f"- Total requests: {summary['total_requests']}",
        f"- Passed: {summary['passed']}",
        f"- Failed: {summary['failed']}",
        f"- Pass rate: {summary['pass_rate']}%",
        f"- Average latency: {summary['avg_ms']} ms",
        f"- P95 latency: {summary['p95_ms']} ms",
        f"- Maximum latency: {summary['max_ms']} ms",
        "",
        "## Failure categories",
        "",
    ]
    for name, count in report["failure_categories"].items():
        lines.append(f"- {name}: {count}")
    lines.extend(["", "See `api_2000_query_report.json` for sampled failure details.", ""])
    REPORT_MD.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    started = time.perf_counter()
    snapshot = load_catalog_snapshot()
    install_test_isolation(snapshot)
    recommendation_cases = build_recommendation_cases() + build_related_query_cases()
    RNG.shuffle(recommendation_cases)
    failures: list[dict[str, Any]] = []
    timings: list[float] = []

    with TestClient(app, raise_server_exceptions=False) as client:
        print(f"Running {len(recommendation_cases)} recommendation requests...")
        recommendation_counts = run_recommendations(client, recommendation_cases, failures, timings)
        print("Running 200 chat requests...")
        chat_counts = run_chat_cases(client, recommendation_cases, failures, timings)
        print("Running 150 filter/search/validation requests...")
        misc_counts = run_misc_cases(client, failures, timings)

    total_counts = recommendation_counts + chat_counts + misc_counts
    total = total_counts["passed"] + total_counts["failed"]
    report = {
        "summary": {
            "seed": SEED,
            "total_requests": total,
            "passed": total_counts["passed"],
            "failed": total_counts["failed"],
            "pass_rate": round(total_counts["passed"] / total * 100, 2) if total else 0,
            "avg_ms": round(statistics.mean(timings), 1) if timings else 0,
            "median_ms": round(statistics.median(timings), 1) if timings else 0,
            "p95_ms": round(percentile(timings, 0.95), 1),
            "p99_ms": round(percentile(timings, 0.99), 1),
            "max_ms": round(max(timings), 1) if timings else 0,
            "elapsed_seconds": round(time.perf_counter() - started, 1),
            "catalog_counts": {key: len(value) for key, value in snapshot.items()},
            "recommendation_requests": len(recommendation_cases),
            "chat_requests": 200,
            "misc_requests": 150,
        },
        "sections": {
            "recommendations": dict(recommendation_counts),
            "chat": dict(chat_counts),
            "misc": dict(misc_counts),
        },
        "failure_categories": {
            key: value
            for key, value in total_counts.items()
            if key not in ("passed", "failed")
        },
        "sampled_failures": failures,
        "methodology": {
            "api_layer": "FastAPI TestClient against the real routes",
            "catalog": "one real Firestore snapshot reused for the large run",
            "chat_external_calls": "live web verification and OpenRouter replaced with deterministic local functions",
        },
    }
    write_reports(report)
    print(json.dumps(report["summary"], indent=2))
    print("Failure categories:", report["failure_categories"])
    print(f"Reports: {REPORT_JSON} and {REPORT_MD}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
