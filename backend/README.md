# Backend (FastAPI)

This folder contains the FastAPI backend.
All APIs, AI logic, database access, and authentication live here.

## Environment

Set environment variables in the repository root `.env` file.

Required for LLM explanations:

- `OPENROUTER_API_KEY`
- `OPENROUTER_MODEL` (example: `openai/gpt-oss-120b:free`)

Optional:

- `OPENROUTER_BASE_URL` (default: `https://openrouter.ai/api/v1`)
- `OPENROUTER_SITE_URL`
- `OPENROUTER_APP_NAME`

Firebase path (if needed by your local setup):

- `FIREBASE_CREDENTIALS_PATH=backend/firebase-key.json`

## Install

From repository root:

`pip install -r backend/requirements.txt`

## Run

From repository root:

`uvicorn backend.app.main:app --reload`
