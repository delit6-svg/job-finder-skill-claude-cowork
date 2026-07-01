#!/usr/bin/env python3
import sys, json, os, tempfile
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode
TRACKING = {"utm_source","utm_medium","utm_campaign","utm_term","utm_content",
            "gclid","fbclid","mc_cid","mc_eid","ref","refid","referrer","source",
            "trk","trkinfo","trackinfo","trackingid","li_fat_id","savedsearchid",
            "origin","originalsubdomain","src","spm","eboriginid","recommended"}
def normalize(u):
    u = (u or "").strip()
    if not u: return ""
    if "://" not in u: u = "https://" + u
    p = urlsplit(u)
    host = (p.hostname or "").lower()
    if host.startswith("www."): host = host[4:]
    if p.port: host = f"{host}:{p.port}"
    path = p.path.rstrip("/") or "/"
    q = [(k,v) for k,v in parse_qsl(p.query, keep_blank_values=True) if k.lower() not in TRACKING]
    q.sort()
    return urlunsplit(("https", host, path, urlencode(q), ""))
def load_seen(path):
    if not os.path.exists(path): return set()
    try:
        with open(path, encoding="utf-8") as f: data = json.load(f)
    except Exception: return set()
    return {normalize(x) for x in data if isinstance(x, str)}
def read_urls(path):
    with open(path, encoding="utf-8") as f: return [l.strip() for l in f if l.strip()]
def do_filter(seen, urls):
    out, emitted = [], set()
    for u in urls:
        n = normalize(u)
        if n and n not in seen and n not in emitted:
            emitted.add(n); out.append(u)
    return out
def do_add(seen_path, urls):
    seen = load_seen(seen_path)
    for u in urls:
        n = normalize(u)
        if n: seen.add(n)
    with open(seen_path, "w", encoding="utf-8") as f:
        json.dump(sorted(seen), f, ensure_ascii=False, indent=0)
    return len(seen)
def selftest():
    n = normalize
    seed = n("https://www.linkedin.com/jobs/view/12345/")
    same = [
        "http://www.linkedin.com/jobs/view/12345/?utm_source=x&trk=y",
        "https://linkedin.com/jobs/view/12345?refId=z",
        "https://www.linkedin.com/jobs/view/12345",
        "  https://www.linkedin.com/jobs/view/12345/  ",
        "https://www.linkedin.com/jobs/view/12345#apply",
        "linkedin.com/jobs/view/12345",
        "HTTPS://WWW.LINKEDIN.COM/jobs/view/12345/",
    ]
    for s in same:
        assert n(s) == seed, ("should-dup", s, n(s))
    assert n("https://linkedin.com/jobs/view/99999") != seed
    assert n("https://il.indeed.com/job/1") != n("https://indeed.com/job/1")
    assert n("https://x.co/j?id=1") != n("https://x.co/j?id=2")
    assert n("https://x.co/j?id=1&a=2&utm_source=q") == n("https://x.co/j?a=2&id=1")
    assert n("https://drushim.co.il/%D7%9E%D7%A9%D7%A8%D7%94/123/") == n("https://drushim.co.il/%D7%9E%D7%A9%D7%A8%D7%94/123")
    assert n("") == "" and n("   ") == ""
    d = tempfile.mkdtemp(); seenp = os.path.join(d, "s.json")
    with open(seenp, "w") as f: f.write("{ not valid json")
    assert load_seen(seenp) == set()
    with open(seenp, "w") as f: json.dump(["https://www.alljobs.co.il/job/100/", 42, None], f)
    cand = ["http://alljobs.co.il/job/100?utm_medium=x", "https://alljobs.co.il/job/200",
            "https://alljobs.co.il/job/200/", "", "  "]
    seen = load_seen(seenp)
    out = do_filter(seen, cand)
    assert out == ["https://alljobs.co.il/job/200"], ("filter", out)
    c1 = do_add(seenp, out); c2 = do_add(seenp, out)
    assert c1 == c2 == 2, ("add", c1, c2)
    assert do_filter(load_seen(seenp), cand) == [], "all seen now"
    print("OK")
def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "selftest":
        selftest(); return
    if len(sys.argv) < 4:
        sys.stderr.write("usage: dedupe.py {filter|add|selftest} <seen.json> <urls.txt>\n"); sys.exit(2)
    seen_path, urls_path = sys.argv[2], sys.argv[3]
    seen = load_seen(seen_path); urls = read_urls(urls_path)
    if mode == "filter":
        sys.stdout.write("\n".join(do_filter(seen, urls)))
    elif mode == "add":
        sys.stdout.write(str(do_add(seen_path, urls)))
    else:
        sys.stderr.write("unknown mode\n"); sys.exit(2)
if __name__ == "__main__": main()
