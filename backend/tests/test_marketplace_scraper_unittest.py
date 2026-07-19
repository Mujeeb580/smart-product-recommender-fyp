import unittest

from app.scraping.marketplace_scraper import _extract_price, _is_laptop_name, _is_phone_name


class MarketplaceScraperTests(unittest.TestCase):
    def test_price_parser_prefers_the_real_currency_amount(self):
        text = "A6000 AI Wireless Remote Gimbal with Auto Face Tracking Special Price Rs 5,999.00 was Rs 7,499.00"
        self.assertEqual(_extract_price(text), "Rs 5,999.00")

    def test_phone_filter_rejects_accessories_but_keeps_actual_phones(self):
        self.assertFalse(_is_phone_name("A6000 AI Wireless Remote Gimbal with Auto Face Tracking"))
        self.assertTrue(_is_phone_name("Samsung Galaxy A57 5G 12GB 256GB"))

    def test_laptop_filter_rejects_accessories_but_keeps_actual_laptops(self):
        self.assertFalse(_is_laptop_name("Laptop Bag 15.6 inch"))
        self.assertTrue(_is_laptop_name("Acer Nitro V 16S ANV16S Intel Core 9 270H 16GB 1TB SSD Gaming Laptop"))


if __name__ == "__main__":
    unittest.main()
