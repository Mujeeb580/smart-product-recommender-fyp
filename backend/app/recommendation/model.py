# backend/app/recommendation/model.py

import torch
from transformers import AutoModel, AutoTokenizer
from threading import Lock

_model = None
_model_lock = Lock()


class SentenceBertEmbedder:
    def __init__(self, model_name: str = "sentence-transformers/all-MiniLM-L6-v2"):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModel.from_pretrained(model_name)
        self.model.to(self.device)
        self.model.eval()

    def encode(self, texts):
        if isinstance(texts, str):
            texts = [texts]

        encoded = self.tokenizer(
            texts,
            padding=True,
            truncation=True,
            max_length=256,
            return_tensors="pt",
        )
        encoded = {k: v.to(self.device) for k, v in encoded.items()}

        with torch.no_grad():
            outputs = self.model(**encoded)

        token_embeddings = outputs.last_hidden_state
        attention_mask = encoded["attention_mask"].unsqueeze(-1).expand(token_embeddings.size()).float()
        summed = (token_embeddings * attention_mask).sum(dim=1)
        counts = attention_mask.sum(dim=1).clamp(min=1e-9)
        sentence_embeddings = summed / counts
        normalized = torch.nn.functional.normalize(sentence_embeddings, p=2, dim=1)
        return normalized.cpu().numpy()

def get_model():
    global _model
    if _model is None:
        with _model_lock:
            if _model is None:
                _model = SentenceBertEmbedder()
    return _model
