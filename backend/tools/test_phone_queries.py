"""Run a broad set of phone queries through ranking and explanation."""

from __future__ import annotations

from typing import Iterable

from app.recommendation.engine import recommend_products
from app.recommendation.firestore import fetch_products
from app.services.llm_service import generate_explanation
from app.services.web_verifier import build_verification_context


PHONE_QUERIES: tuple[str, ...] = (
    "gaming phone",
    "best gaming phone under 100000",
    "good battery life phone",
    "phone with long battery backup",
    "social media phone",
    "phone for instagram tiktok youtube",
    "study phone for online classes and notes",
    "phone for students",
    "best camera phone",
    "balanced all rounder phone",
    "cheap phone for daily use",
    "flagship phone",
    "phone with 12gb ram and 256gb storage",
    "phone for pubg",
    "phone for social media and battery",
)


def _format_product(product: dict) -> str:
    return (
        f"{product.get('name')} | score={product.get('device_score')} | "
        f"tier={product.get('device_tier')} | cpu={product.get('normalized_processor') or product.get('processor')} | "
        f"battery={product.get('battery')} | ram={product.get('ram')} | price={product.get('price')}"
    )


def run_queries(queries: Iterable[str] = PHONE_QUERIES, top_n: int = 3) -> None:
    phones = fetch_products("phones")
    print(f"Loaded {len(phones)} phones from Firestore")
    print("=" * 80)

    for index, query in enumerate(queries, start=1):
        print(f"\n[{index}] QUERY: {query}")
        ranked = recommend_products(query, phones, top_n=top_n)
        verification_context = build_verification_context(query, ranked)
        reply = generate_explanation(query, ranked, verification_context=verification_context)

        if not ranked:
            print("  No ranked results")
            print(f"  AI: {reply}")
            continue

        print(f"  Web: {verification_context.get('summary')}")
        for rank, product in enumerate(ranked, start=1):
            print(f"  {rank}. {_format_product(product)}")
        print(f"  AI: {reply}")


if __name__ == "__main__":
    run_queries()