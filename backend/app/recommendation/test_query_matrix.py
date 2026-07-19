"""Broad evaluator-style coverage for realistic and technical user queries."""

import unittest
from unittest.mock import patch

import numpy as np

from app.recommendation import engine
from app.recommendation.query_language import normalize_user_query, response_language
from app.services.llm_service import _fallback_explanation


class _ZeroEmbedder:
    def encode(self, texts):
        return np.zeros((len(texts), 2), dtype=float)


def _item(name, category, price, brand, **specs):
    return {
        "id": name.lower().replace(" ", "-"),
        "name": name,
        "category": category,
        "price": price,
        "brand": brand,
        "device_score": specs.pop("device_score", 0.5),
        **specs,
    }


CATALOG = [
    _item(
        "Redmi Value", "Phones", 28_000, "Xiaomi", processor="Helio G85",
        ram="4GB", storage="64GB", battery="5000mAh", camera="50MP",
        display="6.5 inch 90Hz LCD", network="4G", charging="18W charging",
        operating_system="Android 14", specs={"Fingerprint": "Side-mounted"},
    ),
    _item(
        "Nokia Easy", "Phones", 36_000, "Nokia", processor="Snapdragon 680",
        ram="4GB", storage="128GB", battery="5000mAh", camera="50MP",
        display="6.6 inch 90Hz LCD", network="4G", charging="20W charging",
        operating_system="Android 14", specs={"Warranty": "1 year", "Weight": "190g"},
    ),
    _item(
        "Samsung Social 5G", "Phones", 55_000, "Samsung", processor="Exynos 1380",
        ram="8GB", storage="128GB", battery="6000mAh", camera="50MP OIS",
        display="6.6 inch 120Hz AMOLED", network="5G NFC", charging="25W charging",
        operating_system="Android 14", device_score=0.70,
        specs={"Fingerprint": "In-display", "Warranty": "1 year"},
    ),
    _item(
        "Infinix Battery Max", "Phones", 47_000, "Infinix", processor="Helio G99",
        ram="8GB", storage="256GB", battery="7000mAh", camera="64MP",
        display="6.8 inch 120Hz AMOLED", network="4G NFC", charging="67W charging",
        operating_system="Android 14", device_score=0.65,
    ),
    _item(
        "Pixel Camera", "Phones", 180_000, "Google", processor="Tensor G3",
        ram="8GB", storage="256GB", battery="4575mAh", camera="50MP OIS flagship camera",
        display="6.7 inch 120Hz OLED", network="5G NFC", charging="30W charging",
        operating_system="Android 15", device_score=0.94,
    ),
    _item(
        "ROG Gaming", "Phones", 250_000, "Asus", processor="Snapdragon 8 Elite",
        ram="16GB", storage="512GB", battery="6000mAh", camera="50MP",
        display="6.8 inch 165Hz AMOLED", network="5G NFC", charging="65W charging",
        operating_system="Android 15", device_score=0.98,
    ),
    _item(
        "Student Book", "Laptops", 85_000, "Lenovo", processor="Core i3-1215U",
        ram="8GB", storage="256GB SSD", battery="5000mAh", gpu="Intel UHD integrated",
        display="14 inch FHD", operating_system="Windows 11",
        specs={"Keyboard": "Standard", "WiFi": "WiFi 5"},
    ),
    _item(
        "Office Pro", "Laptops", 135_000, "HP", processor="Core i5-1335U",
        ram="16GB", storage="512GB SSD", battery="6000mAh", gpu="Intel Iris Xe integrated",
        display="14 inch FHD IPS", operating_system="Windows 11 Pro",
        specs={"Keyboard": "Backlit keyboard", "WiFi": "WiFi 6", "Weight": "1.35kg"},
        device_score=0.70,
    ),
    _item(
        "Gaming 4060", "Laptops", 320_000, "Acer", processor="Core i7-13700H",
        ram="16GB", storage="1TB SSD", battery="6000mAh", gpu="RTX 4060 8GB",
        display="15.6 inch 165Hz IPS", operating_system="Windows 11",
        specs={"Keyboard": "Backlit keyboard", "WiFi": "WiFi 6"}, device_score=0.90,
    ),
    _item(
        "Creator 4080", "Laptops", 620_000, "Asus", processor="Core i9-14900HX",
        ram="32GB", storage="2TB SSD", battery="9000mAh", gpu="RTX 4080 12GB",
        display="16 inch 240Hz OLED", operating_system="Windows 11 Pro",
        specs={"Keyboard": "Backlit keyboard", "Ports": "Thunderbolt 4", "WiFi": "WiFi 6"},
        device_score=0.99,
    ),
]


class ComprehensiveQueryMatrixTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model_patch = patch.object(engine, "get_model", return_value=_ZeroEmbedder())
        cls.model_patch.start()

    @classmethod
    def tearDownClass(cls):
        cls.model_patch.stop()

    def setUp(self):
        engine._EMBEDDING_CACHE.clear()

    def _recommend(self, query, top_n=10):
        return engine.recommend_products(query, CATALOG, top_n=top_n)

    def test_ordinary_user_intent_matrix(self):
        cases = (
            ("best gaming phone", "ROG Gaming"),
            ("PUBG mobile with strong performance", "ROG Gaming"),
            ("phone with the best battery", "Infinix Battery Max"),
            ("long battery mobile for travel", "Infinix Battery Max"),
            ("best camera phone", "Pixel Camera"),
            ("flagship camera mobile", "Pixel Camera"),
            ("gaming laptop", "Creator 4080"),
            ("RTX laptop for AAA games", "Creator 4080"),
            ("gaming laptop under 350000", "Gaming 4060"),
            ("laptop for office documents and meetings", "Office Pro"),
            ("coding laptop for daily work", "Office Pro"),
            ("student laptop under 100k", "Student Book"),
            ("phone under 30000", "Redmi Value"),
            ("Samsung phone", "Samsung Social 5G"),
        )
        for query, expected in cases:
            with self.subTest(query=query):
                results = self._recommend(query)
                self.assertTrue(results)
                self.assertEqual(results[0]["name"], expected)

    def test_workload_fit_handles_paraphrases_negation_and_language(self):
        light_queries = (
            "i am student dont do lot of work just need laptops for basics",
            "I only need a simple notebook for browsing and assignments",
            "I do not need gaming or heavy performance, just university tasks",
            "student hun sirf basic parhai aur browsing ke liye laptop chahiye",
            "میں طالبعلم ہوں، صرف بنیادی پڑھائی اور براؤزنگ کے لیے لیپ ٹاپ چاہیے",
            "میں طالب علم ہوں، صرف پڑھائی اور بنیادی کام کے لیے سستا لیپ ٹاپ چاہیے، گیمنگ نہیں",
        )
        for query in light_queries:
            with self.subTest(query=query):
                self.assertEqual(engine._workload_level(normalize_user_query(query)), "light")
                self.assertEqual(self._recommend(query, top_n=1)[0]["name"], "Student Book")

        demanding_query = "I am a student and need a laptop for machine learning and 3D rendering"
        self.assertEqual(engine._workload_level(demanding_query), "high")
        self.assertEqual(self._recommend(demanding_query, top_n=1)[0]["name"], "Creator 4080")

    def test_light_use_explanation_does_not_call_overkill_the_goal(self):
        query = "I only need a basic laptop for study"
        products = self._recommend(query, top_n=2)
        reply = _fallback_explanation(query, products)
        self.assertIn("practical match", reply)
        self.assertIn("without paying for unnecessary high-end hardware", reply)

    def test_negated_urdu_gaming_request_gets_basic_use_explanation(self):
        query = "میں طالب علم ہوں، بنیادی کام کے لیے لیپ ٹاپ چاہیے، گیمنگ نہیں"
        products = self._recommend(query, top_n=2)
        reply = _fallback_explanation(query, products)
        self.assertNotIn("dedicated-GPU gaming laptop", reply)
        self.assertEqual(products[0]["name"], "Student Book")

    def test_senior_and_basic_use_across_languages(self):
        queries = (
            "I am elderly and need a phone for calls WhatsApp and Facebook",
            "I need an easy mobile for my senior father for calling and social media",
            "buzurg walid ke liye calling whatsapp aur facebook ka mobile chahiye",
            "umar rasida shakhs ke liye asaan phone daily use ke liye",
            "میں بزرگ ہوں، کالنگ، واٹس ایپ اور سوشل میڈیا کے لیے فون چاہیے",
            "عمر رسیدہ والد کے لیے روزمرہ استعمال کا آسان موبائل بتائیں",
        )
        for query in queries:
            with self.subTest(query=query):
                results = self._recommend(query)
                self.assertTrue(results)
                self.assertIn(results[0]["name"], {"Nokia Easy", "Samsung Social 5G", "Infinix Battery Max"})
                self.assertNotEqual(results[0]["name"], "ROG Gaming")
                self.assertTrue(engine._is_senior_phone_query(normalize_user_query(query)))

    def test_english_roman_urdu_and_urdu_equivalence(self):
        groups = (
            (
                "phone with best battery", "sab se achi battery wala mobile batao",
                "سب سے اچھی بیٹری والا موبائل بتاؤ", "Infinix Battery Max",
            ),
            (
                "gaming phone", "gaming ke liye mobile chahiye",
                "گیمنگ کے لیے موبائل چاہیے", "ROG Gaming",
            ),
            (
                "student laptop under 100000", "student ke liye 1 lakh se kam laptop",
                "طالبعلم کے لیے ۱۰۰۰۰۰ سے کم لیپ ٹاپ چاہیے", "Student Book",
            ),
        )
        for english, roman, urdu, expected in groups:
            for query in (english, roman, urdu):
                with self.subTest(query=query):
                    self.assertEqual(self._recommend(query)[0]["name"], expected)

    def test_budget_and_category_constraints_matrix(self):
        cases = (
            ("phone under 50k", "phones", None, 50_000),
            ("mobile below PKR 60,000", "phones", None, 60_000),
            ("mujhe 50 hazar ke andar phone chahiye", "phones", None, 50_000),
            ("مجھے ۵۰ ہزار سے کم فون چاہیے", "phones", None, 50_000),
            ("laptop up to 150000", "laptops", None, 150_000),
            ("2 lakh ke under laptop", "laptops", None, 200_000),
            ("۲ لاکھ سے کم لیپ ٹاپ", "laptops", None, 200_000),
            ("phone between 40000 and 60000", "phones", 40_000, 60_000),
            ("laptop above 300000", "laptops", 300_000, None),
        )
        for query, category, minimum, maximum in cases:
            with self.subTest(query=query):
                results = self._recommend(query)
                self.assertTrue(results)
                for product in results:
                    self.assertEqual(engine._category_of(product), category)
                    price = engine._price_to_float(product["price"])
                    if minimum is not None:
                        self.assertGreaterEqual(price, minimum)
                    if maximum is not None:
                        self.assertLessEqual(price, maximum)

    def test_technical_hard_constraints_matrix(self):
        cases = (
            ("5G phone", lambda p: "5g" in engine._product_feature_text(p)),
            ("phone with AMOLED display", lambda p: "amoled" in engine._product_feature_text(p)),
            ("OLED phone", lambda p: "oled" in engine._product_feature_text(p)),
            ("phone with 120 Hz display", lambda p: "120hz" in engine._product_feature_text(p).replace(" ", "")),
            ("phone with NFC", lambda p: "nfc" in engine._product_feature_text(p)),
            ("phone with 67W fast charging", lambda p: "67w" in engine._product_feature_text(p).replace(" ", "")),
            ("laptop with WiFi 6", lambda p: "wifi 6" in engine._product_feature_text(p)),
            ("laptop with backlit keyboard", lambda p: "backlit keyboard" in engine._product_feature_text(p)),
            ("laptop with Thunderbolt", lambda p: "thunderbolt" in engine._product_feature_text(p)),
            ("gaming laptop RTX 4060", lambda p: "rtx 4060" in str(p.get("gpu", "")).lower()),
            ("phone with 16GB RAM", lambda p: engine._memory_values(p)[0] >= 16),
            ("phone with 512GB storage", lambda p: engine._memory_values(p)[1] >= 512),
            ("laptop with 1TB SSD", lambda p: engine._memory_values(p)[1] >= 1024),
            ("Core i7 laptop", lambda p: "core i7" in str(p.get("processor", "")).lower()),
        )
        for query, predicate in cases:
            with self.subTest(query=query):
                results = self._recommend(query)
                self.assertTrue(results)
                self.assertTrue(all(predicate(product) for product in results))

    def test_typos_and_no_result_safety(self):
        typo_cases = (
            ("moblie under 30000", "phones"),
            ("phoen with best battery", "phones"),
            ("laptpo for student", "laptops"),
            ("leptop for gaming", "laptops"),
        )
        for query, category in typo_cases:
            with self.subTest(query=query):
                results = self._recommend(query)
                self.assertTrue(results)
                self.assertTrue(all(engine._category_of(p) == category for p in results))

        impossible = (
            "phone under 1000", "laptop under 10000", "phone with 32GB RAM",
            "RTX 4090 laptop under 100000", "phone with 240Hz AMOLED under 20000",
        )
        for query in impossible:
            with self.subTest(query=query):
                self.assertEqual(self._recommend(query), [])

    def test_product_question_matrix_and_language(self):
        product = next(item for item in CATALOG if item["name"] == "Nokia Easy")
        known_questions = (
            ("What is its battery?", "5000mAh"),
            ("How much storage does it have?", "128GB"),
            ("What is its warranty?", "1 year"),
            ("اس کی وارنٹی کتنی ہے؟", "1 year"),
            ("اس کا وزن کیا ہے؟", "190g"),
        )
        for query, fact in known_questions:
            with self.subTest(query=query):
                self.assertIn(fact, _fallback_explanation(query, [product]))

        unknown_questions = (
            "Does it have NFC?", "What is its refresh rate?", "Is there a webcam?",
            "کیا اس میں فنگرپرنٹ ہے؟",
        )
        for query in unknown_questions:
            with self.subTest(query=query):
                reply = _fallback_explanation(query, [product])
                self.assertTrue("won't guess" in reply or "andaza nahi" in reply or "اندازہ نہیں" in reply)

        self.assertEqual(response_language("Recommend a phone"), "english")
        self.assertEqual(response_language("mujhe phone chahiye"), "roman_urdu")
        self.assertEqual(response_language("مجھے فون چاہیے"), "roman_urdu")

    def test_normalization_does_not_confuse_model_numbers_with_money(self):
        cases = (
            ("RTX 3050 laptop under 150000", "rtx3050", 150_000),
            ("RTX 4060 laptop under 350k", "rtx4060", 350_000),
            ("Core i7 laptop below 200000", "core i7", 200_000),
        )
        for query, required, budget in cases:
            with self.subTest(query=query):
                constraints = engine._parse_query_constraints(normalize_user_query(query))
                actual = constraints["required_gpu"] or constraints["required_processor"]
                self.assertEqual(actual, required)
                self.assertEqual(constraints["budget_max"], budget)


if __name__ == "__main__":
    unittest.main()
