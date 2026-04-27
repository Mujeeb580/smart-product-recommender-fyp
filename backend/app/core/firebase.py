import firebase_admin
from firebase_admin import credentials, firestore
import os

backend_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
repo_root = os.path.abspath(os.path.join(backend_root, ".."))
default_path = os.path.join(backend_root, "firebase-key.json")


def resolve_cred_path() -> str:
	env_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
	if not env_path:
		return default_path

	if os.path.isabs(env_path):
		return env_path

	sep_norm = env_path.replace("\\", "/")
	candidates = [
		os.path.abspath(env_path),
		os.path.join(backend_root, env_path),
		os.path.join(repo_root, env_path),
	]

	if sep_norm.startswith("backend/"):
		trimmed = sep_norm.split("/", 1)[1]
		candidates.append(os.path.join(backend_root, trimmed))

	for candidate in candidates:
		if os.path.exists(candidate):
			return os.path.abspath(candidate)

	# Fallback to the shell-resolved absolute path for a clear error message.
	return os.path.abspath(env_path)


cred_path = resolve_cred_path()

if not os.path.exists(cred_path):
	raise FileNotFoundError(f"firebase-key.json not found at {cred_path}")

cred = credentials.Certificate(cred_path)

firebase_admin.initialize_app(cred)

firestore_db = firestore.client()
