import asyncio
import unittest
from unittest.mock import patch

import numpy as np

from app.api import chat_routes
from app.recommendation import engine
from app.recommendation.processor_engine import phone_chipset_performance


class _ZeroEmbedder:
    def encode(self, texts):
        return np.zeros((len(texts), 2), dtype=float)


def _product(name, category, price, **specs):
    return {
        "id": name.lower().replace(" ", "-"),
        "name": name,
        "category": category,
        "price": price,
        "device_score": specs.pop("device_score", 0.5),
        **specs,
    }


class RecommendationConstraintTests(unittest.TestCase):
    def setUp(self):
        engine._EMBEDDING_CACHE.clear()
        self.model_patch = patch.object(engine, "get_model", return_value=_ZeroEmbedder())
        self.model_patch.start()

    def tearDown(self):
        self.model_patch.stop()

    def test_common_pakistani_budget_formats(self):
        self.assertEqual(engine._extract_budget("phone under Rs. 50,000"), 50_000)
        self.assertEqual(engine._extract_budget("maximum budget is 100k"), 100_000)
        self.assertEqual(engine._extract_budget("laptop budget 1.5 lakh"), 150_000)
        self.assertEqual(engine._extract_price_constraints("between 50 and 80k"), (50_000, 80_000))

    def test_roman_urdu_laptop_budget_is_a_hard_limit(self):
        products = [
            _product("Within Budget", "Laptops", 199_999, processor="Core i7-1355U"),
            _product(
                "Over Budget", "Laptops", 992_999,
                processor="Core i9-14900HX", gpu="RTX 4090",
            ),
        ]
        for query in ("laptop 2 lac ke under", "2 laac se kam laptop dikhao"):
            results = engine.recommend_products(query, products)
            self.assertEqual([item["name"] for item in results], ["Within Budget"])
            self.assertTrue(
                all(engine._price_to_float(item["price"]) <= 200_000 for item in results)
            )

    def test_explicit_budget_never_returns_over_budget_fallback(self):
        products = [
            _product("Affordable Phone", "Phones", "PKR 49,999"),
            _product("Expensive Phone", "Phones", "Rs. 120,000", device_score=1.0),
        ]
        results = engine.recommend_products("best phone under 50k", products)
        self.assertEqual([item["name"] for item in results], ["Affordable Phone"])
        self.assertLessEqual(engine._price_to_float(results[0]["price"]), 50_000)

    def test_best_under_budget_prefers_capability_over_the_cheapest_item(self):
        products = [
            _product(
                "Cheap Basic", "Phones", 20_000, processor="Unisoc T7250",
                ram="4GB", storage="64GB", battery="5000mAh",
            ),
            _product(
                "Strong Within Budget", "Phones", 49_000, processor="Snapdragon 685",
                ram="8GB", storage="256GB", battery="7000mAh",
            ),
        ]
        results = engine.recommend_products("best phone under 50k", products)
        self.assertEqual(results[0]["name"], "Strong Within Budget")

    def test_unknown_chipset_with_more_ram_does_not_automatically_win(self):
        products = [
            _product(
                "Unknown 12GB", "Phones", 33_000, processor="Unknown",
                ram="12GB", storage="128GB", battery="6000mAh",
            ),
            _product(
                "Known Balanced", "Phones", 45_000, processor="Snapdragon 685",
                ram="8GB", storage="128GB", battery="7000mAh",
            ),
        ]
        results = engine.recommend_products("best phone under 50k", products)
        self.assertEqual(results[0]["name"], "Known Balanced")

    def test_cheapest_query_still_prefers_the_lowest_price(self):
        products = [
            _product("Cheapest", "Phones", 20_000, processor="Unisoc T7250"),
            _product("Stronger", "Phones", 49_000, processor="Snapdragon 685"),
        ]
        results = engine.recommend_products("cheapest phone under 50k", products)
        self.assertEqual(results[0]["name"], "Cheapest")

    def test_impossible_hard_constraints_return_no_results(self):
        products = [_product("Premium Laptop", "Laptops", 250_000, ram="16 GB")]
        self.assertEqual(engine.recommend_products("laptop under 100k", products), [])
        self.assertEqual(engine.recommend_products("laptop with 32gb ram", products), [])

    def test_storage_tb_is_compared_as_gigabytes(self):
        products = [
            _product("Large Laptop", "Laptops", 200_000, storage="1 TB"),
            _product("Small Laptop", "Laptops", 150_000, storage="256 GB"),
        ]
        results = engine.recommend_products("laptop with 512gb storage", products)
        self.assertEqual([item["name"] for item in results], ["Large Laptop"])
        self.assertEqual(engine._parse_query_constraints("laptop with 1tb ssd")["min_storage"], 1024)

    def test_generic_budget_does_not_apply_phone_limit_to_laptops(self):
        products = [
            _product("Value Laptop", "Laptops", 120_000),
            _product("Premium Laptop", "Laptops", 300_000),
        ]
        results = engine.recommend_products("budget laptop", products)
        self.assertEqual(results[0]["name"], "Value Laptop")

    def test_brand_query_is_not_overridden_by_unrelated_quality_score(self):
        products = [
            _product("Samsung A", "Phones", 80_000, brand="Samsung", device_score=0.5),
            _product("Other Flagship", "Phones", 90_000, brand="Other", device_score=1.0),
        ]
        results = engine.recommend_products("best Samsung phone", products)
        self.assertEqual([item["brand"] for item in results], ["Samsung"])

    def test_request_for_phone_and_laptop_returns_both_categories(self):
        products = [
            _product("Phone A", "Phones", 60_000, device_score=1.0),
            _product("Phone B", "Phones", 70_000, device_score=0.9),
            _product("Laptop A", "Laptops", 150_000, device_score=0.4),
        ]
        results = engine.recommend_products("recommend a phone and laptop", products, top_n=2)
        self.assertEqual({item["category"] for item in results}, {"Phones", "Laptops"})

    def test_large_mixed_catalog_preserves_both_categories_during_preselection(self):
        products = [
            _product(f"Phone {index}", "Phones", 40_000 + index, processor="Helio G81")
            for index in range(100)
        ] + [
            _product("Laptop A", "Laptops", 140_000, processor="Core i5", ram="16GB", storage="512GB"),
            _product("Laptop B", "Laptops", 150_000, processor="Core i7", ram="16GB", storage="512GB"),
        ]
        results = engine.recommend_products("recommend a phone and laptop under 200k", products, top_n=5)
        self.assertEqual({item["category"] for item in results}, {"Phones", "Laptops"})

    def test_large_budget_catalog_keeps_strong_gaming_candidate(self):
        products = [
            _product(
                f"Cheap Phone {index}", "Phones", 20_000 + index,
                processor="Helio G81", gpu="Mali-G52", ram="8GB", storage="128GB", battery="5000mAh",
            )
            for index in range(100)
        ] + [
            _product(
                "Real Gaming Choice", "Phones", 155_000,
                processor="Dimensity 8400", gpu="Mali-G720 MC7", ram="12GB", storage="256GB", battery="6500mAh",
            )
        ]
        results = engine.recommend_products("best gaming phone under 160k", products, top_n=5)
        self.assertEqual(results[0]["name"], "Real Gaming Choice")

    def test_laptop_cpu_can_be_recovered_from_product_name(self):
        product = _product(
            "HP Victus Core i7-13620H RTX 5060", "Laptops", 350_000,
            processor="Intel", gpu="RTX 5060", ram="16GB", storage="512GB",
        )
        self.assertGreaterEqual(engine._product_processor_score(product), 0.84)

    def test_newer_laptop_cpu_beats_old_same_tier_cpu(self):
        old = _product(
            "Old Core i7-1065G7", "Laptops", 120_000,
            processor="Quad Core", gpu="Built-In Graphics Card",
            ram="8GB", storage="512GB",
        )
        new = _product(
            "New Core i7-1355U", "Laptops", 198_000,
            processor="Core i7-1355U", gpu="Intel Iris Xe Graphics",
            ram="8GB", storage="512GB",
        )
        self.assertGreater(
            engine._product_processor_score(new),
            engine._product_processor_score(old),
        )
        for query in ("best laptop under 2 lac", "laptop 2 lac ke under"):
            results = engine.recommend_products(query, [old, new])
            self.assertEqual(results[0]["name"], "New Core i7-1355U")

    def test_gaming_ranking_uses_chip_generation_not_stale_device_score(self):
        products = [
            _product(
                "Old Stored Winner", "Phones", 100_000,
                processor="Snapdragon 7s Gen 4", gpu="Adreno 810", ram="12GB",
                storage="512GB", battery="6500mAh", device_score=0.99,
            ),
            _product(
                "Actual Flagship", "Phones", 200_000,
                processor="Snapdragon 8 Elite", gpu="Adreno 830", ram="12GB",
                storage="256GB", battery="5000mAh", device_score=0.50,
            ),
        ]
        results = engine.recommend_products("best gaming phone", products)
        self.assertEqual(results[0]["name"], "Actual Flagship")
        self.assertGreater(results[0]["intent_score"], results[1]["intent_score"])
        self.assertNotEqual(results[1]["device_score"], 0.99)

    def test_new_dimensity_gaming_phone_beats_old_snapdragon_generation(self):
        products = [
            _product(
                "New Gaming Phone", "Phones", 150_000,
                processor="Dimensity 8400 Ultimate", gpu="Mali-G720 MC7", ram="12GB",
                storage="256GB", battery="6500mAh",
            ),
            _product(
                "Old Flagship", "Phones", 140_000,
                processor="Snapdragon 8 Gen 1", gpu="Adreno 730", ram="12GB",
                storage="256GB", battery="5000mAh",
            ),
        ]
        results = engine.recommend_products("gaming phone", products)
        self.assertEqual(results[0]["name"], "New Gaming Phone")

    def test_chipset_generation_scores_are_ordered(self):
        scores = [
            phone_chipset_performance({"processor": processor})
            for processor in (
                "Snapdragon 8 Elite Gen 5",
                "Snapdragon 8 Elite",
                "Snapdragon 8 Gen 3",
                "Snapdragon 8s Gen 3",
                "Snapdragon 8 Gen 1",
                "Snapdragon 7s Gen 4",
                "Snapdragon 6 Gen 4",
            )
        ]
        self.assertEqual(scores, sorted(scores, reverse=True))
        self.assertEqual(len(scores), len(set(scores)))

    def test_swapped_ram_and_storage_fields_are_repaired_for_ranking(self):
        product = _product("Swapped Phone", "Phones", 100_000, ram="1TB", storage="16GB")
        self.assertEqual(engine._memory_values(product), (16, 1024))

    def test_best_battery_query_prioritizes_actual_capacity(self):
        products = [
            _product("Fast 5000", "Phones", 150_000, processor="Snapdragon 8 Elite", battery="5000mAh"),
            _product("Long 8300", "Phones", 120_000, processor="Snapdragon 6 Gen 4", battery="8300mAh"),
        ]
        results = engine.recommend_products("phone with best battery", products)
        self.assertEqual(results[0]["name"], "Long 8300")

    def test_camera_ranking_does_not_treat_megapixels_as_the_only_quality_signal(self):
        products = [
            _product(
                "Budget 200MP", "Phones", 60_000, processor="Helio G99",
                camera="200 MP", ram="8GB", storage="256GB", battery="5000mAh",
            ),
            _product(
                "Flagship 50MP", "Phones", 200_000, processor="Snapdragon 8 Elite",
                camera="50 MP", ram="12GB", storage="256GB", battery="5000mAh",
            ),
        ]
        results = engine.recommend_products("best camera phone", products)
        self.assertEqual(results[0]["name"], "Flagship 50MP")

    def test_escaped_new_laptop_gpu_is_ranked_by_generation(self):
        products = [
            _product(
                "RTX 5060 Laptop", "Laptops", 500_000, processor="Core Ultra 9",
                gpu="RTX 5060 8GB", ram="32GB", storage="1TB",
            ),
            _product(
                "RTX 5080 Laptop", "Laptops", 900_000, processor="Core Ultra 9",
                gpu=r"NVIDIA\ GeForce RTX\ 5080 16GB", ram="32GB", storage="1TB",
            ),
        ]
        results = engine.recommend_products("best gaming laptop", products)
        self.assertEqual(results[0]["name"], "RTX 5080 Laptop")
        self.assertGreater(results[0]["intent_score"], results[1]["intent_score"])

    def test_gaming_laptop_gpu_class_outweighs_cpu_tier(self):
        products = [
            _product(
                "I7 RTX 4060", "Laptops", 350_000, processor="Core i7-13700H",
                gpu="RTX 4060 8GB", ram="16GB", storage="512GB",
            ),
            _product(
                "I9 RTX 4050", "Laptops", 340_000, processor="Core i9-13900H",
                gpu="RTX 4050 6GB", ram="16GB", storage="512GB",
            ),
        ]
        results = engine.recommend_products("best gaming laptop", products)
        self.assertEqual(results[0]["name"], "I7 RTX 4060")


class ChatContextTests(unittest.TestCase):
    def setUp(self):
        chat_routes._SESSION_CONTEXT.clear()
        self.products = [
            _product("Phone A", "Phones", 50_000, battery="5000 mAh"),
            _product("Phone B", "Phones", 60_000, battery="6000 mAh"),
        ]

    def _recommend(self, query, products, top_n=5):
        if "battery" in query.lower():
            return sorted(products, key=lambda item: engine._battery_value(item), reverse=True)[:top_n]
        return list(products)[:top_n]

    def test_typed_follow_up_uses_prior_recommendations(self):
        with patch.object(chat_routes, "_load_products", return_value=self.products), patch.object(
            chat_routes, "recommend_products", side_effect=self._recommend
        ), patch.object(chat_routes, "build_verification_context", return_value={}), patch.object(
            chat_routes, "generate_explanation", return_value="Phone B has the larger battery."
        ):
            first = asyncio.run(chat_routes.send_chat_message(
                chat_routes.ChatMessage(message="recommend a phone", session_id="test-session")
            ))
            follow_up = asyncio.run(chat_routes.send_chat_message(
                chat_routes.ChatMessage(message="which one has better battery?", session_id="test-session")
            ))

        self.assertEqual(len(first["products"]), 2)
        self.assertEqual(follow_up["products"][0]["name"], "Phone B")
        self.assertEqual(follow_up["reply"], "Phone B has the larger battery.")

    def test_product_id_can_match_firestore_document_id(self):
        with patch.object(chat_routes, "_load_products", return_value=self.products), patch.object(
            chat_routes, "generate_explanation", return_value="Focused answer"
        ):
            response = asyncio.run(chat_routes.send_chat_message(
                chat_routes.ChatMessage(message="is its battery good?", product_id="phone-a")
            ))
        self.assertEqual(response["products"][0]["name"], "Phone A")


if __name__ == "__main__":
    unittest.main()
