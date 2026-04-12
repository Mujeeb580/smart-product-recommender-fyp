import firebase_admin
from firebase_admin import credentials, firestore
import os

default_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../firebase-key.json"))
env_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
cred_path = os.path.abspath(env_path) if env_path else default_path

if not os.path.exists(cred_path):
	raise FileNotFoundError(f"firebase-key.json not found at {cred_path}")

cred = credentials.Certificate(cred_path)

firebase_admin.initialize_app(cred)

firestore_db = firestore.client()
