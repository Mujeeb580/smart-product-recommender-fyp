import unittest
from types import SimpleNamespace

from fastapi import HTTPException

import app.api.admin_routes as routes


class _Snapshot:
    def __init__(self, data):
        self._data = data

    @property
    def exists(self):
        return self._data is not None

    def to_dict(self):
        return dict(self._data or {})


class _Document:
    def __init__(self, store, document_id):
        self._store = store
        self.id = document_id

    def get(self):
        return _Snapshot(self._store.get(self.id))

    def set(self, data):
        self._store[self.id] = dict(data)

    def delete(self):
        self._store.pop(self.id, None)


class _Collection:
    def __init__(self, store):
        self._store = store

    def document(self, document_id=None):
        return _Document(self._store, document_id or f"id-{len(self._store) + 1}")

    def stream(self):
        return [SimpleNamespace(id=key) for key in self._store]

    def limit(self, _value):
        return self


class _Firestore:
    def __init__(self):
        self.data = {
            "products": {},
            "phones": {},
            "laptops": {},
            "chat_history": {},
        }

    def collection(self, name):
        return _Collection(self.data.setdefault(name, {}))


class _UsersPage:
    def iterate_all(self):
        metadata = SimpleNamespace(creation_timestamp=1, last_sign_in_timestamp=2)
        return iter(
            [
                SimpleNamespace(
                    uid="user-1",
                    email="user@example.com",
                    display_name="Test User",
                    disabled=False,
                    email_verified=True,
                    user_metadata=metadata,
                    provider_data=[],
                )
            ]
        )


class _FirebaseAuth:
    class UserNotFoundError(Exception):
        pass

    def __init__(self):
        self.deleted = []

    def list_users(self, max_results=1000):
        return _UsersPage()

    def delete_user(self, uid):
        self.deleted.append(uid)


class AdminRouteTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.old_db = routes.firestore_db
        self.old_auth = routes.auth
        self.old_phone_scraper = routes.scrape_phones
        self.old_laptop_scraper = routes.scrape_laptops
        self.db = _Firestore()
        self.auth = _FirebaseAuth()
        routes.firestore_db = self.db
        routes.auth = self.auth
        routes._admin_sessions.clear()

    def tearDown(self):
        routes.firestore_db = self.old_db
        routes.auth = self.old_auth
        routes.scrape_phones = self.old_phone_scraper
        routes.scrape_laptops = self.old_laptop_scraper
        routes._admin_sessions.clear()

    async def test_login_session_and_logout(self):
        with self.assertRaises(HTTPException) as invalid:
            await routes.admin_login(
                routes.AdminLoginRequest(
                    username="admin@fyndo.com",
                    password="wrong",
                )
            )
        self.assertEqual(invalid.exception.status_code, 401)

        login = await routes.admin_login(
            routes.AdminLoginRequest(
                username="admin@fyndo.com",
                password="Admin@123",
            )
        )
        token = login["token"]
        self.assertEqual(routes._require_admin(f"Bearer {token}"), token)
        await routes.admin_logout(f"Bearer {token}")
        with self.assertRaises(HTTPException):
            routes._require_admin(f"Bearer {token}")

    async def test_product_create_update_move_and_delete(self):
        created = await routes.create_product(
            {
                "collection": "phones",
                "name": "Test Phone",
                "brand": "Test",
                "price": 100,
                "category": "Phones",
            }
        )
        product_id = created["product"]["id"]
        self.assertIn(product_id, self.db.data["phones"])

        updated = await routes.update_product(
            "phones",
            product_id,
            {
                "collection": "laptops",
                "name": "Test Laptop",
                "brand": "Test",
                "price": 200,
                "category": "Laptops",
            },
        )
        self.assertEqual(updated["product"]["price"], 200)
        self.assertNotIn(product_id, self.db.data["phones"])
        self.assertIn(product_id, self.db.data["laptops"])

        await routes.delete_product("laptops", product_id)
        self.assertNotIn(product_id, self.db.data["laptops"])

    async def test_user_listing_and_deletion(self):
        result = await routes.admin_users(limit=500)
        self.assertEqual(result["count"], 1)
        self.assertEqual(result["users"][0]["email"], "user@example.com")

        await routes.delete_user("user-1")
        self.assertEqual(self.auth.deleted, ["user-1"])

    async def test_each_scraper_mode_dispatches_correctly(self):
        calls = []
        routes.scrape_phones = lambda stop_on_existing=False, max_pages=100, max_products=0: calls.append(
            ("phones", stop_on_existing)
        ) or {"saved": 1, "updated": 0}
        routes.scrape_laptops = lambda stop_on_existing=False, max_pages=100, max_products=0: calls.append(
            ("laptops", stop_on_existing)
        ) or {"saved": 2, "updated": 1}

        expected = {
            "phones": [("phones", False)],
            "laptops": [("laptops", False)],
            "all": [("phones", False), ("laptops", False)],
            "new_phones": [("phones", True)],
            "new_laptops": [("laptops", True)],
        }
        for mode, expected_calls in expected.items():
            calls.clear()
            result = routes._run_scraper_mode(mode, max_pages=1, max_products=2)
            self.assertTrue(result["ok"])
            self.assertEqual(calls, expected_calls)


if __name__ == "__main__":
    unittest.main()
