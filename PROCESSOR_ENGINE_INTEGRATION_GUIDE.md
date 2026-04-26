## Processor Engine Integration Guide

Complete guide for the Smart Product Recommender System processor performance scoring module.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Backend Integration](#backend-integration)
4. [Frontend Integration](#frontend-integration)
5. [API Endpoints](#api-endpoints)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The **Processor Engine** is a deterministic scoring system that evaluates phone performance based on:
- **Processor/Chipset** (60% weight)
- **RAM** (20% weight)
- **Battery Capacity** (10% weight)
- **Release Year/Recency** (10% weight)

### Key Features
✅ **No LLM dependencies** - Rule-based pure Python  
✅ **Deterministic** - Same input always produces same output  
✅ **Scalable** - Easily extendable to laptops/tablets  
✅ **Production-ready** - Error handling for missing data  
✅ **Fast** - Pure regex and dictionary lookups  

---

## System Architecture

```
┌─────────────────────────────────────────────────────┐
│           Firebase Phone Database                    │
│  (processor, gpu, ram, battery, release_date)       │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│   Backend API Routes (product_routes.py)             │
│  • /products/phones/performance                      │
│  • /products/phones/by-tier                          │
│  • /products/phones/score-details                    │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│     Processor Engine (processor_engine.py)           │
│  • Normalize processor names                         │
│  • Calculate scores from chipset DB                  │
│  • GPU-based fallback scoring                        │
│  • Performance breakdown calculation                 │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│      Flutter Frontend (Provider Pattern)             │
│  • ProductProvider manages state                     │
│  • ProductService calls APIs                         │
│  • UI displays scores and tiers                      │
└─────────────────────────────────────────────────────┘
```

---

## Backend Integration

### File Structure
```
backend/
├── app/
│   ├── api/
│   │   └── product_routes.py          ← MODIFIED: Added scoring endpoints
│   ├── recommendation/
│   │   └── processor_engine.py         ← NEW: Scoring logic
│   ├── core/
│   │   └── firebase.py
│   └── services/
│       └── llm_service.py
└── requirements.txt
```

### Key Changes in `product_routes.py`

#### 1. Import processor_engine
```python
from app.recommendation.processor_engine import calculate_phone_score
```

#### 2. Helper Functions
```python
def _add_processor_score(product: dict) -> dict:
    """Add processor performance score to phone products"""
    # Only for phones
    # Calls calculate_phone_score()
    # Returns product with added fields:
    #   - processor_score (0-1)
    #   - processor_tier (Flagship/Upper Mid/Mid/Low)
    #   - normalized_processor
    #   - performance_breakdown
```

#### 3. New Endpoints Added

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/products/phones/performance` | GET | Get phones sorted by score |
| `/products/phones/by-tier` | GET | Filter by processor tier |
| `/products/phones/score-details` | POST | Get detailed breakdown |

---

## Frontend Integration

### File Structure (Flutter)
```
lib/
├── core/
│   └── api_config.dart             ← UPDATED: Added new endpoints
├── models/
│   └── product_model.dart          ← UPDATED: Added score fields
├── services/
│   └── product_service.dart        ← UPDATED: Added scoring methods
├── providers/
│   └── product_provider.dart       ← NEW: State management
└── features/
    └── products/
        ├── product_list_screen.dart
        ├── product_detail_screen.dart
        └── product_card_widget.dart
```

### Key Model Fields Added
```dart
class ProductModel {
  // ... existing fields ...
  
  // Processor performance scoring (NEW)
  final double? processorScore;        // 0.0 to 1.0
  final String? processorTier;         // Flagship, Upper Mid, Mid, Low
  final String? normalizedProcessor;   // Clean chipset name
  final PerformanceBreakdown? performanceBreakdown;  // Score breakdown
}

class PerformanceBreakdown {
  final double? baseChipsetScore;      // Chipset tier score
  final double? ramScore;              // RAM normalized
  final double? batteryScore;          // Battery normalized
  final double? recencyScore;          // Year-based
}
```

### Service Methods Added
```dart
class ProductService {
  // Get phones by performance score
  Future<List<ProductModel>> getPhonesByPerformance({
    int limit = 20,
    double? minScore,
    String? tier,
  })
  
  // Get phones by tier
  Future<List<ProductModel>> getPhonesByTier(
    String tier, {int limit = 20})
  
  // Get detailed score info
  Future<Map<String, dynamic>> getPhoneScoreDetails(
    String productId)
}
```

### Provider Usage
```dart
// In Widget
Consumer<ProductProvider>(
  builder: (context, provider, _) {
    return provider.isLoading
        ? CircularProgressIndicator()
        : ListView(
            children: provider.products.map((phone) {
              return ProductCard(
                product: phone,
                showScore: true,  // Display processor score
              );
            }).toList(),
          );
  },
)

// Load data
provider.loadPhonesByPerformance(minScore: 0.8);
provider.loadPhonesByTier('Flagship');
```

---

## API Endpoints

### 1. Get Phones by Performance Score

**Request:**
```http
GET /products/phones/performance?limit=20&min_score=0.8&tier=Flagship
```

**Parameters:**
- `limit`: Max items (default: 20)
- `min_score`: Minimum score 0.0-1.0 (optional)
- `tier`: Flagship | Upper Mid | Mid | Low (optional)

**Response:**
```json
{
  "products": [
    {
      "id": "product_123",
      "name": "Samsung Galaxy S24",
      "processor": "Snapdragon 8 Gen 3",
      "ram": "12GB",
      "battery": "7000mAh",
      "processor_score": 0.97,
      "processor_tier": "Flagship",
      "normalized_processor": "Snapdragon 8 Gen 3",
      "performance_breakdown": {
        "base_chipset_score": 0.97,
        "ram_score": 1.0,
        "battery_score": 1.0,
        "recency_score": 0.9
      }
    }
  ],
  "count": 1,
  "filters": {
    "min_score": 0.8,
    "tier": "Flagship",
    "limit": 20
  }
}
```

### 2. Get Phones by Tier

**Request:**
```http
GET /products/phones/by-tier?tier=Flagship&limit=10
```

**Response:**
```json
{
  "products": [
    { /* phone objects */ }
  ],
  "tier": "Flagship",
  "count": 5
}
```

### 3. Get Score Details

**Request:**
```http
POST /products/phones/score-details?product_id=123abc
```

**Response:**
```json
{
  "product": {
    "id": "123abc",
    "name": "iPhone 15 Pro",
    "processor": "Apple A17 Pro",
    "ram": "8GB",
    "battery": "3200mAh"
  },
  "score": {
    "overall": 0.93,
    "tier": "Flagship",
    "normalized_processor": "Apple A17 Pro",
    "breakdown": {
      "base_chipset_score": 0.95,
      "ram_score": 0.67,
      "battery_score": 0.46,
      "recency_score": 0.9
    }
  }
}
```

---

## Testing

### Backend Test Suite

Run the comprehensive test suite:
```bash
cd g:\FYP\smart-product-recommender-fyp
python test_processor_engine.py
```

**Test Coverage:**
- ✅ Phones by Performance endpoint
- ✅ Score filtering (min_score parameter)
- ✅ Phones by Tier endpoint
- ✅ Phone Score Details endpoint
- ✅ Recommendations with processor scores
- ✅ Chat integration with scores

### Manual Testing

#### Test 1: Get High-End Phones
```bash
curl "http://127.0.0.1:8000/products/phones/performance?min_score=0.85&limit=5"
```

#### Test 2: Get Flagship Phones
```bash
curl "http://127.0.0.1:8000/products/phones/by-tier?tier=Flagship"
```

#### Test 3: Get Score Details
```bash
curl -X POST "http://127.0.0.1:8000/products/phones/score-details?product_id=YOUR_PRODUCT_ID"
```

### Unit Tests (Python)
```python
from backend.app.recommendation.processor_engine import calculate_phone_score

# Test 1: Flagship phone
result = calculate_phone_score({
    "processor": "Snapdragon 8 Gen 3",
    "gpu": "Adreno 830",
    "ram": "12GB",
    "battery": "7000mAh",
    "release_date": "2024"
})
assert result['score'] > 0.9
assert result['tier'] == 'Flagship'

# Test 2: Budget phone with unknown processor
result = calculate_phone_score({
    "processor": "UnknownChip XYZ",
    "gpu": "Mali-G57 MP1",
    "ram": "4GB",
    "battery": "5000mAh"
})
assert result['score'] < 0.5
assert result['tier'] == 'Unknown'

# Test 3: Processor name normalization
result = calculate_phone_score({
    "processor": "SD 695",  # Messy input
    "gpu": "Adreno 720",
    "ram": "6GB",
    "battery": "5500mAh"
})
assert result['normalized_processor'] == 'Snapdragon 695'
assert result['tier'] == 'Mid'
```

---

## Troubleshooting

### Issue 1: ImportError for processor_engine
**Error:** `ModuleNotFoundError: No module named 'app.recommendation.processor_engine'`

**Solution:**
1. Verify file location: `backend/app/recommendation/processor_engine.py`
2. Ensure `backend/app/recommendation/__init__.py` exists (can be empty)
3. Run from backend directory: `cd backend && python ...`

### Issue 2: No processor scores showing in response
**Error:** Products returned without `processor_score` field

**Solution:**
1. Verify phone has `processor` or `gpu` field
2. Check if product category contains "phone" or "mobile"
3. Ensure product_routes.py has `_add_processor_score()` being called

### Issue 3: Unknown tier for all phones
**Error:** All phones showing `processor_tier: "Unknown"`

**Solution:**
1. Check processor name matches CHIPSET_DB keys
2. Update CHIPSET_DB if using new processors
3. GPU fallback scoring may need adjustment

### Issue 4: Score always 0.5 (GPU fallback)
**Error:** Scores stuck at 0.5 for all products

**Solution:**
1. Processor name may not be in CHIPSET_DB
2. GPU not recognized in infer_score_from_gpu()
3. Add missing processor/GPU to database

---

## Performance Optimization

### Caching Scores
```python
# Optional: Cache scores in Firestore for faster lookup
def cache_phone_scores():
    """Pre-calculate and cache all phone scores"""
    phones = fetch_products("phones")
    for phone in phones:
        score_result = calculate_phone_score(phone)
        phone['cached_processor_score'] = score_result
        firestore_db.collection('phones').document(phone['id']).set(
            score_result, merge=True
        )
```

### Load Testing
```bash
# Load test with 1000 concurrent requests
ab -n 1000 -c 50 http://127.0.0.1:8000/products/phones/performance?limit=10
```

---

## Database Expansion

### Adding New Processors to CHIPSET_DB
```python
CHIPSET_DB = {
    # ... existing entries ...
    "Snapdragon 9 Gen 1": {"tier": "Flagship", "score": 0.88},  # NEW
    "MediaTek Dimensity 9300": {"tier": "Flagship", "score": 0.96},  # NEW
}
```

### Adding New GPU Fallback Rules
```python
def infer_score_from_gpu(gpu_str: str) -> float:
    # ... existing code ...
    
    # New GPU rule
    if 'adreno 9xx' in gpu_lower:
        return 0.95  # NEW
    
    return 0.50  # default
```

---

## Production Deployment Checklist

- [ ] CHIPSET_DB covers all processors in your dataset
- [ ] Test all API endpoints thoroughly
- [ ] Monitor error rates and latency
- [ ] Cache processor scores in Firestore
- [ ] Add rate limiting to score endpoints
- [ ] Implement request validation
- [ ] Set up monitoring/alerting
- [ ] Document API in Swagger/OpenAPI
- [ ] Train team on score interpretation
- [ ] Plan quarterly DB updates for new processors

---

## Reference Documentation

- **Processor Engine Code:** `backend/app/recommendation/processor_engine.py`
- **API Routes:** `backend/app/api/product_routes.py`
- **Frontend Service:** `frontend/flutter_application_1/lib/services/product_service.dart`
- **Test Suite:** `test_processor_engine.py`
- **Integration Guide:** `INTEGRATION_GUIDE.md`

---

## Support

For issues or questions:
1. Check Troubleshooting section
2. Review test results from `test_processor_engine.py`
3. Check processor_engine.py docstrings
4. Verify Firestore data has required fields (processor, gpu, ram, battery)
