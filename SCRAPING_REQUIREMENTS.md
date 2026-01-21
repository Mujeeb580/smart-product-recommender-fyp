# Priceoye.pk Web Scraping Requirements

## Website Analysis: https://priceoye.pk/

### Overview
Priceoye.pk is a Pakistani e-commerce platform selling electronic products including:
- Mobiles
- Smart Watches
- Wireless Earbuds
- Laptops
- Tablets
- Power Banks
- Mobile Chargers
- Bluetooth Speakers
- Air Purifiers
- Personal Care Items (Trimmers, Hair Dryers, etc.)

---

## Data to Scrape from Listing Pages

### From Product Listings (e.g., Home Page, Category Pages)

For each product card/listing, extract:

1. **Product Name** - Full product title
   - Example: "Samsung Galaxy A17"

2. **Brand** - Manufacturer name
   - Example: "Samsung"

3. **Product URL** - Link to product detail page
   - Example: "https://priceoye.pk/mobiles/samsung/samsung-galaxy-a17"

4. **Price** - Current selling price in PKR
   - Example: "Rs 51,199"

5. **Original Price** - Before discount
   - Example: "Rs 56,500"

6. **Discount Percentage** - Off percentage
   - Example: "9% OFF"

7. **Rating** - Star rating (1-5)
   - Example: "4.9"

8. **Number of Reviews** - Review count
   - Example: "31 Reviews"

9. **Category** - Product category
   - Example: "mobiles", "wireless-earbuds", "smart-watches", "power-banks", etc.

10. **Product Image URL** - Thumbnail/main image URL
    - Example: "https://images.priceoye.pk/samsung-galaxy-a17-pakistan-priceoye-s9wf0-500x500.webp"

11. **Badge/Label** - Any special badges/labels
    - Examples: "fast badge", "Official Retailer Badge", "New Arrival"

12. **Availability Status** - In stock/Out of stock
    - May need to check page load/JavaScript

---

## Data to Scrape from Product Detail Pages

### Example Product Detail Page:
https://priceoye.pk/mobiles/samsung/samsung-galaxy-a17

Extract the following information:

1. **Basic Information** (from listing also available here)
   - Product Name
   - Brand
   - Current Price
   - Original Price
   - Discount %
   - Rating & Reviews

2. **Product Specifications** (Key differentiator from listings)
   - **For Mobiles:**
     - Processor/Chipset
     - RAM (GB)
     - Storage Options (GB)
     - Display Size (inches)
     - Display Type (IPS, AMOLED, etc.)
     - Resolution
     - Battery Capacity (mAh)
     - Camera: Rear MP
     - Camera: Front MP
     - Operating System (Android version)
     - 5G Support (Yes/No)
     - Weight (grams)
     - Dimensions
     - Color Options

   - **For Smart Watches:**
     - Display Type
     - Band Material
     - Water Resistance Rating (ATM/IP rating)
     - Battery Life
     - Sensors
     - Connectivity (Bluetooth, WiFi, NFC)
     - Compatible OS (iOS, Android)
     - Available Straps

   - **For Wireless Earbuds:**
     - Driver Size (mm)
     - Frequency Response
     - Impedance
     - Connectivity (Bluetooth version)
     - Battery Life (Single charge)
     - Case Battery Life
     - Charging Time
     - Waterproof/Water Resistance Rating
     - Noise Cancellation (Yes/No)

   - **For Laptops:**
     - Processor Brand & Model
     - Processor Generation
     - RAM (GB)
     - Storage Type (SSD/HDD)
     - Storage Capacity (GB)
     - Display Size (inches)
     - Display Resolution
     - Graphics Card
     - Operating System
     - Battery Life (hours)
     - Weight (kg)

   - **For Power Banks:**
     - Capacity (mAh)
     - Input Power (W)
     - Output Power (W)
     - Number of Ports
     - Weight
     - Dimensions
     - Type (Wired/Wireless)

3. **Product Details Section**
   - Full description/overview
   - Features list
   - Warranty information
   - Additional accessories included

4. **Similar Products**
   - Alternative/competitor products recommended
   - Can use for recommendation system

5. **Reviews Section** (if accessible)
   - Reviewer name
   - Review date
   - Rating given
   - Review text
   - Verified purchase badge

6. **Pricing Information**
   - Available payment plans/installment options
   - Extended warranty offers
   - Gift wrap option pricing

7. **Product Images**
   - All product images (multiple angles)
   - High-resolution image URLs

---

## Page Categories to Scrape

1. **Main Categories:**
   - Mobiles: `https://priceoye.pk/mobiles` or `https://priceoye.pk/store`
   - Smart Watches: `https://priceoye.pk/smart-watches`
   - Wireless Earbuds: `https://priceoye.pk/wireless-earbuds`
   - Laptops: `https://priceoye.pk/laptops`
   - Tablets: `https://priceoye.pk/tablets`
   - Power Banks: `https://priceoye.pk/power-banks`
   - Mobile Chargers: `https://priceoye.pk/mobile-chargers`
   - Bluetooth Speakers: `https://priceoye.pk/bluetooth-speakers`
   - Air Purifiers: `https://priceoye.pk/air-purifiers`
   - Personal Care: `https://priceoye.pk/personal-cares`

2. **Filter/Price Range Pages:**
   - Example: `https://priceoye.pk/mobiles/pricelist?price_range=15000to25000`

3. **Brand-Specific Pages:**
   - Example: `https://priceoye.pk/mobiles/samsung`

---

## Technical Notes for Scraping

### HTML Structure Notes:
- **Product Cards:** Contain product information in structured card layout
- **Dynamic Content:** Some content may be loaded via JavaScript (lazy loading)
- **Pagination:** Need to handle multiple pages (next/prev buttons or infinite scroll)
- **Images:** Lazy loaded, may need to wait for load

### Challenges:
1. **JavaScript Rendering:** Website may use React/Vue for dynamic content loading
   - Solution: Use Selenium, Playwright, or Puppeteer for JavaScript rendering

2. **Rate Limiting:** Website may block rapid requests
   - Solution: Add delays between requests, use rotating proxies

3. **User-Agent Blocking:** May require proper User-Agent headers
   - Solution: Set realistic User-Agent strings

4. **CAPTCHA/Bot Detection:** Possible anti-scraping measures
   - Solution: Use appropriate delays, headers, and user behavior simulation

### Recommended Approach:
1. **Browser-based scraping** (Selenium/Playwright) for JavaScript rendering
2. **BeautifulSoup** for HTML parsing after page loads
3. **Respect robots.txt** and add delays (2-5 seconds between requests)
4. **Store data in structured format** (JSON, CSV, or Database)
5. **Implement error handling** for network failures and page variations

---

## Data Storage Structure (Suggested)

### Product Listing Data:
```json
{
  "product_id": "unique_identifier",
  "name": "Product Name",
  "brand": "Brand Name",
  "category": "Category Name",
  "url": "Full URL to product page",
  "price": "Current price in PKR",
  "original_price": "Original price",
  "discount_percentage": 9,
  "rating": 4.9,
  "reviews_count": 31,
  "image_url": "Product image URL",
  "badges": ["fast", "official_retailer"],
  "scraped_date": "2026-01-17"
}
```

### Product Details Data:
```json
{
  "product_id": "unique_identifier",
  "basic_info": { ...listing data... },
  "specifications": {
    "category_specific_specs": "..."
  },
  "description": "Full product description",
  "warranty": "Warranty details",
  "images": ["url1", "url2", "url3"],
  "similar_products": ["product_id1", "product_id2"],
  "reviews": [
    {
      "reviewer": "Name",
      "rating": 5,
      "date": "2026-01-15",
      "text": "Review text...",
      "verified": true
    }
  ],
  "scraped_date": "2026-01-17"
}
```

---

## Priority Scraping Order:
1. Start with Mobiles category (largest product range)
2. Then Smart Watches, Wireless Earbuds
3. Then other categories
4. For each product listing, immediately scrape its detail page
5. Store all data in database for easy querying

---

## Notes for FYP Smart Product Recommender:
- Product specifications are crucial for building recommendation algorithm
- Price comparisons across similar products
- Ratings/reviews important for quality assessment
- Category information helps in grouping products
- Similar products section can be used for collaborative filtering
