"""Evaluate recommendation ranking accuracy and latency against Firestore data."""

from __future__ import annotations

import statistics
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.recommendation.engine import (
    _battery_value,
    _category_of,
    _device_quality_score,
    _gpu_tier_score,
    _memory_values,
    _price_to_float,
    _product_processor_score,
    recommend_products,
)
from app.recommendation.firestore import fetch_products


Check = Callable[[list[dict], list[dict]], tuple[bool, str]]


@dataclass(frozen=True)
class Scenario:
    query: str
    catalog: str
    check: Check


def _all(results: list[dict], predicate: Callable[[dict], bool], label: str) -> tuple[bool, str]:
    if not results:
        return False, "no results"
    failed = [item.get("name", "Unknown") for item in results if not predicate(item)]
    return (not failed, label if not failed else f"failed: {', '.join(failed)}")


def _category(category: str) -> Check:
    return lambda results, _: _all(results, lambda item: _category_of(item) == category, category)


def _max_price(maximum: float, category: str) -> Check:
    return lambda results, _: _all(
        results,
        lambda item: _category_of(item) == category and 0 < _price_to_float(item.get("price")) <= maximum,
        f"{category}, price <= {maximum:g}",
    )


def _best_under(maximum: float, category: str) -> Check:
    def check(results: list[dict], catalog: list[dict]) -> tuple[bool, str]:
        constraints_ok, detail = _max_price(maximum, category)(results, catalog)
        eligible = [
            item for item in catalog
            if _category_of(item) == category and 0 < _price_to_float(item.get("price")) <= maximum
        ]
        top_quality = _device_quality_score(results[0]) if results else 0
        best_quality = max((_device_quality_score(item) for item in eligible), default=0)
        quality_ok = top_quality >= best_quality - 0.03
        return constraints_ok and quality_ok, f"{detail}; top quality={top_quality:.2f}, available max={best_quality:.2f}"
    return check


def _gaming_phone_budget(maximum: float) -> Check:
    def check(results: list[dict], _: list[dict]) -> tuple[bool, str]:
        constraints_ok, detail = _max_price(maximum, "phones")(results, [])
        performance = _product_processor_score(results[0]) if results else 0
        ok = constraints_ok and performance >= 0.80
        return ok, f"{detail}; top chipset={performance:.2f} (>=0.80)"
    return check


def _gaming_laptop(maximum: float | None = None) -> Check:
    def check(results: list[dict], _: list[dict]) -> tuple[bool, str]:
        if not results:
            return False, "no results"
        gpu_score = _gpu_tier_score(results[0].get("gpu"))
        budget_ok = maximum is None or all(_price_to_float(item.get("price")) <= maximum for item in results)
        category_ok = all(_category_of(item) == "laptops" for item in results)
        ok = category_ok and budget_ok and gpu_score >= 0.80
        return ok, f"top GPU={gpu_score:.2f} (>=0.80); budget_ok={budget_ok}"
    return check


def _battery(results: list[dict], catalog: list[dict]) -> tuple[bool, str]:
    if not results:
        return False, "no results"
    top = _battery_value(results[0])
    catalog_max = max((_battery_value(item) for item in catalog), default=0)
    return top == catalog_max and top > 0, f"top={top}mAh; catalog max={catalog_max}mAh"


def _memory(min_ram: int, min_storage: int, category: str) -> Check:
    return lambda results, _: _all(
        results,
        lambda item: (
            _category_of(item) == category
            and _memory_values(item)[0] >= min_ram
            and _memory_values(item)[1] >= min_storage
        ),
        f"{category}, RAM >= {min_ram}GB, storage >= {min_storage}GB",
    )


def _brand(brand: str, maximum: float) -> Check:
    def check(results: list[dict], catalog: list[dict]) -> tuple[bool, str]:
        constraints_ok, detail = _all(
            results,
            lambda item: (
                str(item.get("brand", "")).lower() == brand.lower()
                and _price_to_float(item.get("price")) <= maximum
            ),
            f"brand={brand}, price <= {maximum:g}",
        )
        eligible = [
            item for item in catalog
            if str(item.get("brand", "")).lower() == brand.lower()
            and 0 < _price_to_float(item.get("price")) <= maximum
        ]
        top_quality = _device_quality_score(results[0]) if results else 0
        best_quality = max((_device_quality_score(item) for item in eligible), default=0)
        quality_ok = top_quality >= best_quality - 0.04
        return constraints_ok and quality_ok, f"{detail}; top quality={top_quality:.2f}, brand max={best_quality:.2f}"
    return check


def _processor_text(token: str, category: str) -> Check:
    return lambda results, _: _all(
        results,
        lambda item: (
            _category_of(item) == category
            and token.lower() in f"{item.get('processor', '')} {item.get('gpu', '')} {item.get('name', '')}".lower()
        ),
        f"{category}, contains {token}",
    )


def _flagship(results: list[dict], _: list[dict]) -> tuple[bool, str]:
    score = _product_processor_score(results[0]) if results else 0
    return score >= 0.95, f"top processor score={score:.2f} (>=0.95)"


def _both_categories(results: list[dict], _: list[dict]) -> tuple[bool, str]:
    categories = {_category_of(item) for item in results}
    budget_ok = all(_price_to_float(item.get("price")) <= 200_000 for item in results)
    return {"phones", "laptops"}.issubset(categories) and budget_ok, f"categories={sorted(categories)}; budget_ok={budget_ok}"


SCENARIOS = (
    Scenario("best gaming phone", "phones", lambda r, _: (bool(r) and r[0].get("intent_score", 0) >= 0.90, f"top intent={r[0].get('intent_score', 0) if r else 0:.2f}")),
    Scenario("best gaming phone under 160k", "phones", _gaming_phone_budget(160_000)),
    Scenario("best phone under Rs. 50,000", "phones", _best_under(50_000, "phones")),
    Scenario("Samsung phone under 150k", "phones", _brand("Samsung", 150_000)),
    Scenario("phone with 12gb ram and 256gb storage", "phones", _memory(12, 256, "phones")),
    Scenario("phone with best battery", "phones", _battery),
    Scenario("fastest flagship phone", "phones", _flagship),
    Scenario("best camera phone", "phones", _category("phones")),
    Scenario("best gaming laptop", "laptops", _gaming_laptop()),
    Scenario("best gaming laptop under 400k", "laptops", _gaming_laptop(400_000)),
    Scenario("best laptop under 150000", "laptops", _best_under(150_000, "laptops")),
    Scenario("laptop with core i7", "laptops", _processor_text("core i7", "laptops")),
    Scenario("laptop with rtx 4060", "laptops", _processor_text("rtx 4060", "laptops")),
    Scenario("laptop with 16gb ram and 512gb storage", "laptops", _memory(16, 512, "laptops")),
    Scenario("recommend a phone and laptop under 200k", "both", _both_categories),
)


def _percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    index = min(len(ordered) - 1, round((len(ordered) - 1) * fraction))
    return ordered[index]


def main() -> None:
    load_started = time.perf_counter()
    phones = fetch_products("phones", 150)
    phones_loaded = time.perf_counter()
    laptops = fetch_products("laptops", 150)
    loaded = time.perf_counter()
    catalogs = {"phones": phones, "laptops": laptops, "both": phones + laptops}

    print(f"CATALOG phones={len(phones)} laptops={len(laptops)}")
    print(f"FETCH phones_ms={(phones_loaded-load_started)*1000:.1f} laptops_ms={(loaded-phones_loaded)*1000:.1f}")

    timings: list[float] = []
    passed = 0
    for index, scenario in enumerate(SCENARIOS, start=1):
        catalog = catalogs[scenario.catalog]
        started = time.perf_counter()
        results = recommend_products(scenario.query, catalog, top_n=5)
        elapsed_ms = (time.perf_counter() - started) * 1000
        timings.append(elapsed_ms)
        ok, detail = scenario.check(results, catalog)
        passed += int(ok)
        top = results[0] if results else {}
        print(
            f"[{index:02d}] {'PASS' if ok else 'FAIL'} {elapsed_ms:8.1f}ms | {scenario.query}\n"
            f"     top={top.get('name', 'NONE')} | price={top.get('price')} | {detail}"
        )

    warm_timings: list[float] = []
    for scenario in SCENARIOS:
        started = time.perf_counter()
        recommend_products(scenario.query, catalogs[scenario.catalog], top_n=5)
        warm_timings.append((time.perf_counter() - started) * 1000)

    print(f"ACCURACY {passed}/{len(SCENARIOS)} ({passed/len(SCENARIOS)*100:.1f}%)")
    print(
        "FIRST_PASS_MS "
        f"avg={statistics.mean(timings):.1f} median={statistics.median(timings):.1f} "
        f"p95={_percentile(timings, .95):.1f} max={max(timings):.1f}"
    )
    print(
        "WARM_PASS_MS "
        f"avg={statistics.mean(warm_timings):.1f} median={statistics.median(warm_timings):.1f} "
        f"p95={_percentile(warm_timings, .95):.1f} max={max(warm_timings):.1f}"
    )


if __name__ == "__main__":
    main()
