import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("firebase-key.json")

firebase_admin.initialize_app(cred)

firestore_db = firestore.client()
