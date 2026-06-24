import json, re, sys

t = open(sys.argv[1]).read()
delim = chr(96) * 3
pattern = delim + "json" + "(.*?)" + delim
blocks = re.findall(pattern, t, re.DOTALL)
for b in blocks:
    b = b.strip()
    if not b.startswith("{"):
        continue
    try:
        d = json.loads(b)
        if "threads" not in d:
            continue
        th = d["threads"][0]
        e = th.get("engagement", {})
        if "quotes" in e and "captured_at" in th:
            sys.exit(0)
    except Exception:
        pass
sys.exit(1)
