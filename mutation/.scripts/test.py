#!/usr/bin/env python3
"""Scenario tests for dedupe.py.  Run:  python3 test.py
Each scenario declares: the CURRENT seen-log, the NEW incoming posts,
and the EXPECTED new output after dedupe. Also checks idempotency."""
import os, json, tempfile, sys
import dedupe

SCENARIOS = [
    {
        "name": "http/https + www + trailing slash + utm all collapse to an already-seen post",
        "seen": ["https://www.linkedin.com/jobs/view/12345/"],
        "new":  ["http://linkedin.com/jobs/view/12345",
                 "https://www.linkedin.com/jobs/view/12345/?utm_source=mail"],
        "expected": [],
    },
    {
        "name": "genuinely new posts pass; internal duplicate collapsed",
        "seen": ["https://alljobs.co.il/job/100"],
        "new":  ["https://alljobs.co.il/job/200",
                 "https://alljobs.co.il/job/200/",
                 "https://drushim.co.il/job/300"],
        "expected": ["https://alljobs.co.il/job/200", "https://drushim.co.il/job/300"],
    },
    {
        "name": "tracking params ignored, but a real id param is respected",
        "seen": ["https://x.co/j?id=1"],
        "new":  ["https://x.co/j?id=1&utm_campaign=z", "https://x.co/j?id=2"],
        "expected": ["https://x.co/j?id=2"],
    },
    {
        "name": "distinct subdomains are different jobs (il.indeed vs indeed)",
        "seen": ["https://indeed.com/job/1"],
        "new":  ["https://il.indeed.com/job/1"],
        "expected": ["https://il.indeed.com/job/1"],
    },
    {
        "name": "blank / whitespace lines are ignored",
        "seen": [],
        "new":  ["", "   ", "https://a.co/1"],
        "expected": ["https://a.co/1"],
    },
    {
        "name": "missing scheme treated as https (so it dedupes against seen)",
        "seen": ["https://jobmaster.co.il/job/55"],
        "new":  ["jobmaster.co.il/job/55"],
        "expected": [],
    },
    {
        "name": "query-param ORDER does not matter (same job, reordered params)",
        "seen": ["https://x.co/job?a=1&b=2"],
        "new":  ["https://x.co/job?b=2&a=1"],
        "expected": [],
    },
]

def run():
    fails = 0
    for sc in SCENARIOS:
        d = tempfile.mkdtemp(); seenp = os.path.join(d, "seen.json")
        with open(seenp, "w", encoding="utf-8") as f: json.dump(sc["seen"], f)
        got = dedupe.do_filter(dedupe.load_seen(seenp), sc["new"])
        ok = (got == sc["expected"])
        dedupe.do_add(seenp, got)
        idem = (dedupe.do_filter(dedupe.load_seen(seenp), sc["new"]) == [])
        ok_all = ok and idem
        fails += 0 if ok_all else 1
        print(f"[{'PASS' if ok_all else 'FAIL'}] {sc['name']}")
        if not ok:
            print(f"        expected: {sc['expected']}")
            print(f"        got:      {got}")
        if not idem:
            print(f"        FAIL: not idempotent (re-running found 'new' posts again)")
    print(f"\n{len(SCENARIOS)-fails}/{len(SCENARIOS)} scenarios passed")
    sys.exit(1 if fails else 0)

if __name__ == "__main__": run()
