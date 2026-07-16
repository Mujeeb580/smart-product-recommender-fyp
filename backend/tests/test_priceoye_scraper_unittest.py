import unittest

import app.scraping.priceoye_scraper as scraper


class _Snapshot:
    def __init__(self, data):
        self._data = data

    @property
    def exists(self):
        return self._data is not None


class _Document:
    def __init__(self, store, document_id):
        self.store = store
        self.id = document_id

    def get(self):
        return _Snapshot(self.store.get(self.id))

    def set(self, data, merge=False):
        if merge and self.id in self.store:
            self.store[self.id].update(data)
        else:
            self.store[self.id] = dict(data)


class _Collection:
    def __init__(self, store):
        self.store = store

    def document(self, document_id):
        return _Document(self.store, document_id)


class _Firestore:
    def __init__(self):
        self.collections = {"phones": {}, "laptops": {}}

    def collection(self, name):
        return _Collection(self.collections.setdefault(name, {}))


class _Element:
    def __init__(self, text="", attributes=None):
        self.text = text
        self.attributes = attributes or {}

    def get_attribute(self, name):
        return self.attributes.get(name)


class _Card:
    def __init__(self, driver, generation, name, price, url):
        self.driver = driver
        self.generation = generation
        self.name = name
        self.price = price
        self.url = url

    def find_element(self, _by, selector):
        if self.driver.generation != self.generation:
            raise RuntimeError("stale card")
        if selector == ".p-title":
            return _Element(self.name)
        if selector == ".price-box span":
            return _Element(self.price)
        if selector == "a":
            return _Element(attributes={"href": self.url})
        if selector == "img":
            return _Element(attributes={"src": f"{self.url}.jpg"})
        raise LookupError(selector)


class _Driver:
    def __init__(self, products):
        self.products = products
        self.generation = 0
        self.current_url = ""
        self.quit_called = False

    def get(self, url):
        self.current_url = url
        self.generation += 1

    def find_elements(self, _by, selector):
        if selector != ".productBox" or "?page=1" not in self.current_url:
            return []
        generation = self.generation
        return [
            _Card(self, generation, product["name"], product["price"], product["url"])
            for product in self.products
        ]

    def quit(self):
        self.quit_called = True


class PriceOyeScraperTests(unittest.TestCase):
    def setUp(self):
        self.old_db = scraper.firestore_db
        self.old_driver = scraper._new_driver
        self.old_detail = scraper._parse_detail_page
        self.old_sleep = scraper.time.sleep
        self.db = _Firestore()
        scraper.firestore_db = self.db
        scraper.time.sleep = lambda _seconds: None
        scraper._parse_detail_page = lambda _driver, url: {
            "specs": {
                "processor": f"CPU-{url[-1]}",
                "ram": "8 GB",
                "storage": "256 GB",
            },
            "image_url": f"{url}-detail.jpg",
        }

    def tearDown(self):
        scraper.firestore_db = self.old_db
        scraper._new_driver = self.old_driver
        scraper._parse_detail_page = self.old_detail
        scraper.time.sleep = self.old_sleep

    def _run(self, products, stop_on_existing=False):
        driver = _Driver(products)
        scraper._new_driver = lambda: driver
        result = scraper.scrape_priceoye_collection(
            base_url="https://example.test/products",
            category_name="Phones",
            firestore_collection="phones",
            stop_on_existing=stop_on_existing,
            max_pages=1,
        )
        self.assertTrue(driver.quit_called)
        return result

    def test_processes_every_card_after_detail_navigation(self):
        products = [
            {"name": "Alpha Phone", "price": "Rs 100", "url": "https://p/1"},
            {"name": "Beta Phone", "price": "Rs 200", "url": "https://p/2"},
        ]
        result = self._run(products)

        self.assertEqual(result["saved"], 2)
        self.assertEqual(result["errors"], 0)
        saved = list(self.db.collections["phones"].values())
        self.assertEqual({item["processor"] for item in saved}, {"CPU-1", "CPU-2"})
        self.assertTrue(all(item["ram"] == "8 GB" for item in saved))

    def test_new_only_stops_at_first_existing_product(self):
        products = [
            {"name": "New Phone", "price": "Rs 100", "url": "https://p/new"},
            {"name": "Old Phone", "price": "Rs 200", "url": "https://p/old"},
            {"name": "Never Reached", "price": "Rs 300", "url": "https://p/later"},
        ]
        old_product = {
            "name": "Old",
            "url": "https://p/old",
            "category": "Phones",
        }
        old_product["normalized_name"] = "Old"
        old_id = scraper._generate_product_id(old_product)
        self.db.collections["phones"][old_id] = {"name": "Old"}

        result = self._run(products, stop_on_existing=True)

        self.assertEqual(result["saved"], 1)
        self.assertEqual(result["updated"], 0)
        self.assertEqual(result["existing_hits"], 1)
        self.assertTrue(result["stopped_on_existing"])
        self.assertEqual(result["total_seen"], 1)
        self.assertEqual(self.db.collections["phones"][old_id], {"name": "Old"})


if __name__ == "__main__":
    unittest.main()
