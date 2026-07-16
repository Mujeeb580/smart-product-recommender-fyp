from app.recommendation.engine import _extract_price_constraints
from app.recommendation.query_language import normalize_user_query, prefers_roman_urdu
from app.services.llm_service import _fallback_explanation


def test_normalizes_phone_budget_and_gaming_intent():
    query = normalize_user_query("Mujhe 80 hazar ke andar acha gaming mobail chahiye")
    assert "under 80 k" in query
    assert "gaming" in query
    assert "mobile" in query
    assert _extract_price_constraints(query) == (None, 80_000.0)


def test_normalizes_laptop_study_query():
    query = normalize_user_query("Parhai ke liye sasta leptop dikhao")
    assert "study" in query
    assert "cheap" in query
    assert "laptop" in query


def test_normalizes_mixed_roman_urdu_laptop_budget_variants():
    for raw in (
        "laptop 2 lac ke under",
        "laptop 2 lac ka under",
        "2 laac se kam laptop dikhao",
        "2 lakhs tak laptop chahiye",
    ):
        query = normalize_user_query(raw)
        assert _extract_price_constraints(query) == (None, 200_000.0), (raw, query)

    assert prefers_roman_urdu("2 laac se kam laptop dikhao")


def test_normalizes_contextual_follow_up():
    query = normalize_user_query("Dusre wale ka processor aur battery batao")
    assert "second" in query
    assert "processor" in query
    assert "battery" in query


def test_detects_roman_urdu_without_misclassifying_english():
    assert prefers_roman_urdu("Mujhe acha camera phone chahiye")
    assert not prefers_roman_urdu("Show me a good camera phone")


def test_roman_urdu_fallback_does_not_duplicate_currency():
    reply = _fallback_explanation(
        "Mujhe acha gaming mobile chahiye",
        [{"name": "Test Phone", "price": "Rs 69,999"}],
    )
    assert "hai" in reply
    assert "Rs. Rs" not in reply


def test_english_and_roman_urdu_gaming_follow_ups_give_verdicts():
    product = {
        "name": "Test Phone",
        "processor": "Dimensity 6300",
        "device_score": 0.55,
    }
    english = _fallback_explanation("Is it worth it for PUBG?", [product])
    roman_urdu = _fallback_explanation("Kya yeh PUBG ke liye acha hai?", [product])
    assert "moderate settings" in english
    assert "moderate settings" in roman_urdu


def test_comparison_follow_up_answers_in_both_languages():
    products = [
        {
            "name": "Second Phone",
            "price": "Rs 60,000",
            "ram": "8GB",
            "intent_score": 0.5,
        },
        {
            "name": "First Phone",
            "price": "Rs 70,000",
            "ram": "12GB",
            "intent_score": 0.8,
        },
    ]
    english = _fallback_explanation("Compare it with the first one", products)
    roman_urdu = _fallback_explanation("Pehle wale se compare karo", products)
    assert "Second Phone" in english and "First Phone" in english
    assert "ranking mein" in roman_urdu
    assert "First Phone ranks higher" in english


def test_gaming_laptop_reply_discloses_integrated_graphics_limit():
    products = [
        {
            "name": "Value Laptop",
            "category": "Laptops",
            "price": "Rs 180,000",
            "gpu": "Intel Iris Xe Graphics",
        }
    ]
    english = _fallback_explanation("gaming laptop under 2 lac", products)
    roman_urdu = _fallback_explanation(
        "gaming laptop 2 lac ke andar dikhao",
        products,
    )
    assert "No dedicated-GPU" in english
    assert "dedicated-GPU gaming laptop nahi mila" in roman_urdu
