import firebase_admin
from firebase_admin import credentials, firestore
import os

# Resolve key path from backend root regardless of current working directory.
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
KEY_PATH = os.path.join(BASE_DIR, "firebase-key.json")

if not firebase_admin._apps:
	cred = credentials.Certificate(KEY_PATH)
	firebase_admin.initialize_app(cred)

firestore_db = firestore.client()
