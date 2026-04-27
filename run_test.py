import json, requests
qs = [
    "hello", "assalam o alaikum", "recommend best earbuds", "best phone under 50000",
    "i need bigger battery phone", "i need best camera phone", "i need gaming phone",
    "i need flagship phone", "i want snapdragon 8 phone", "i need 12gb ram phone 256gb",
    "cheapest 5g phone", "best laptop under 150000", "gaming laptop with strong gpu",
    "i need laptop for coding and battery backup", "i need core i7 laptop",
    "i need rtx 4060 laptop", "lightweight laptop for office",
    "best budget laptop under 100k", "i need macbook style premium laptop",
    "i need tablet for study"
]
out = []
for q in qs:
    try:
        r = requests.post("http://127.0.0.1:8000/chat/send-message", json={"message": q}, timeout=60)
        d = r.json()
        ps = d.get("products") or []
        t3 = []
        for p in ps[:3]:
            t3.append({"name": p.get("name"), "price": p.get("price"), "processor": p.get("processor"), "gpu": p.get("gpu"), "battery": p.get("battery"), "score": p.get("similarity_score")})
        out.append({"query": q, "ok": r.ok, "count": len(ps), "reply": str(d.get("reply", "")), "top3": t3})
    except Exception as e:
        out.append({"query": q, "ok": False, "count": -1, "reply": str(e), "top3": []})
print(json.dumps(out))
