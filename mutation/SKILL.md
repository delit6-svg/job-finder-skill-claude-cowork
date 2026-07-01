# Israel Job-Shortlist — Cowork setup prompt

**How to use:** open Claude **Cowork** and paste everything in the box below into the chat. Claude will ask you a few questions right here in the chat, let you upload your CV, write a small renderer script into your task folder, then create and schedule your daily job-shortlist task. Everything you need is in this one prompt — the renderer is embedded in STEP 0.

---

````
You are setting up a recurring JOB-SHORTLIST task for me in Claude Cowork, tuned for the Israeli job market. Run the setup as a conversation in THIS chat, then register the task. Follow these steps:

STEP 0 — The renderer script. Each scheduled run will NOT hand-build the Excel (that drifts). Instead it
writes the jobs to a JSON file and calls a fixed Python renderer so the format is identical every run.
As part of setup, once we've chosen a kebab-case taskId, create the folder
`C:\Users\<me>\Claude\Scheduled\<taskId>\` and write the file `build_shortlist.py` into it with EXACTLY the
Python content in the "RENDERER SCRIPT" block at the very end of this prompt (verbatim, no edits). Make sure
Python is available with openpyxl (`pip install openpyxl` if needed).

STEP 1 — Ask me for my preferences using the in-chat question UI (AskUserQuestion), a few at a time, not all at once:
  a) My name (for the shortlist banner).
  b) How to decide what to search for: (i) I upload a CV, (ii) I type role keywords, or (iii) both.
     - If I pick CV: ask me to upload my CV file in this chat (PDF/DOCX/TXT) and WAIT for it.
  c) Location in Israel (a city, "anywhere in Israel", or "remote").
  d) Which employment types to INCLUDE (multi-select): Full-time salaried, Part-time, Hourly,
     Temporary (עבודה זמנית), Project/Freelance (פרויקט), One-off/Gig (עבודה חד פעמית).
  e) Seniority target: entry/junior, mid, senior, or any.
  f) Delivery: styled .xlsx to my Desktop (default); optionally also Google Drive and/or email
     (ask for the address if email).
  g) Schedule: daily / weekdays / weekly / no schedule — and the time.

STEP 2 — If I uploaded a CV, READ it now and extract: my profession and role families, core skills,
years of experience, and seniority band. Turn these into concrete Hebrew AND English search keywords.
BAKE the results directly into the task prompt in STEP 3 (do NOT rely on the CV file later — scheduled
runs start fresh and won't have it). If I only gave keywords, use those.

STEP 3 — Build a fully self-contained task prompt (it must work with no memory of this chat) that does,
each run:
  - Search many Israeli boards (AllJobs, Drushim, JobMaster, LinkedIn IL, Indeed IL, Glassdoor IL,
    JobInfo, Ethosia, Geektime/company pages, plus sector boards for my profession), Hebrew + English,
    multiple queries and pages, aiming for ~15–30+ real listings.
  - Apply HARD filters: only the employment types I included (understand HE/EN terms incl. עבודה זמנית /
    פרויקט / עבודה חד פעמית), and my seniority target (by title, reading HE experience phrasing).
  - Drop expired/closed listings.
  - Dedupe against a local file `C:\Users\<me>\Claude\Scheduled\<taskId>\seen-jobs.json` (create if missing;
    normalize URLs; only keep NEW; append and cap ~3000).
  - Group each surviving listing into a short bucket label for my profession (e.g. "B1 Help Desk",
    "B2 L2/Desktop/NOC", …). Keep buckets stable run-to-run.
  - Soft-learn from my feedback: read the Status column of up to the 3 newest prior
    `Job-Shortlist-*.xlsx`; move role-types I marked "✅ Sent/💬 Interviewing" up and
    "❌ Didn't apply/🚫 Rejected" down (never hard-drop). This only changes ORDER, not the format.
  - DO NOT hand-build the Excel. Instead:
      1. Assemble a JSON object with this exact shape and write it to
         `C:\Users\<me>\Claude\Scheduled\<taskId>\jobs.json` (UTF-8):
           {
             "name": "<my name>",
             "date": "<YYYY-MM-DD for today, local>",
             "output_dir": "C:\\Users\\<me>\\Desktop",
             "jobs": [
               {
                 "status": "To apply",          // keep "To apply" for new roles; when re-emitting a
                                                // role I already marked, carry my previous Status over
                 "bucket": "B1 Help Desk",      // the group label from the step above
                 "title":  "<role title>",
                 "company":"<company>",
                 "location":"<city / area>",
                 "source": "<board, e.g. Indeed>",
                 "tag":    "<1 short note, e.g. 'L1 service desk'>",
                 "exp":    "<experience note, e.g. 'no exp' / '2y+' — or omit>",
                 "link":   "https://<direct listing url>"
               }
               // …one object per listing, ordered by bucket then my soft-ranking…
             ]
           }
      2. Run the renderer (it lives next to jobs.json):
           python "C:\Users\<me>\Claude\Scheduled\<taskId>\build_shortlist.py" "C:\Users\<me>\Claude\Scheduled\<taskId>\jobs.json"
         It deterministically writes `Job-Shortlist-YYYY-MM-DD.xlsx` to my Desktop with: the navy banner
         "Job Shortlist — <my name>", a subtitle with date + total + per-bucket counts, columns
         [Status, Bucket, Title, Company, Location, Source, Tag, Exp., Link], a Status DROPDOWN (To apply /
         ✅ Sent / 💬 Interviewing / ❌ Didn't apply / 🚫 Rejected / ⏳ No response), "Open ↗" hyperlinks,
         a frozen header, autofilter, and per-bucket color bands with light/dark row striping. Buckets are
         auto-colored from a fixed palette in first-seen order, so any profession renders consistently.
      3. Confirm the script printed "Wrote N roles…" and that the .xlsx exists; open it once to verify the
         Status dropdown is intact. If `python` isn't found, try `py` or `python3`.
  - Keep jobs.json as the run's data backup. Do the optional Drive/email delivery if I chose it.
  - SHORTLIST ONLY: read public listings; never apply, log in, or submit anything.
  - End with one line: new jobs per bucket, the .xlsx path, and what you favored/down-ranked from my marks.

STEP 4 — Register it: call create_scheduled_task with the kebab-case taskId, the schedule I chose
(cronExpression for daily/weekdays/weekly in my LOCAL time, or none for manual), a one-line description,
and the self-contained prompt from STEP 3. Confirm `build_shortlist.py` from STEP 0 is saved in the task
folder, then confirm the task appears in my Scheduled list.

===================================  RENDERER SCRIPT  ===================================
Write this verbatim to `C:\Users\<me>\Claude\Scheduled\<taskId>\build_shortlist.py`:

```python
#!/usr/bin/env python3
"""build_shortlist.py — deterministic renderer for the Job-Shortlist Excel file.

The scheduled Cowork task gathers/dedupes jobs, writes them to a JSON file, then
calls THIS script. The script builds the styled .xlsx the same way every run, so
the output format is 100% consistent.

USAGE
    python build_shortlist.py <input.json> [output.xlsx]
    - <input.json>   job data (schema in the setup prompt). Required.
    - [output.xlsx]  optional explicit path. If omitted, writes
                     Job-Shortlist-YYYY-MM-DD.xlsx to the Desktop.
"""

import json
import os
import sys
from datetime import date

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

NAVY = "FF1F3864"
BANNER_TITLE = "FFFFFFFF"
BANNER_SUB = "FFD6E0F5"
HEADER_TEXT = "FFFFFFFF"
STATUS_FILL = "FFFFFDE7"
STATUS_TEXT = "FF444444"
LINK_TEXT = "FF0563C1"
BORDER_GREY = "FFBFBFBF"

STATUS_OPTIONS = [
    "To apply", "✅ Sent", "\U0001f4ac Interviewing",
    "❌ Didn't apply", "\U0001f6ab Rejected", "⏳ No response",
]

# (header, key, width, horizontal-align, wrap)
COLUMNS = [
    ("Status",   "status",   15, "center", False),
    ("Bucket",   "bucket",   16, None,     False),
    ("Title",    "title",    38, None,     True),
    ("Company",  "company",  23, None,     True),
    ("Location", "location", 21, None,     False),
    ("Source",   "source",    8, None,     False),
    ("Tag",      "tag",      25, None,     False),
    ("Exp.",     "exp",       7, None,     False),
    ("Link",     "link",      9, "center", False),
]
NCOLS = len(COLUMNS)

# (dark_fill, light_fill, font) assigned to buckets in first-seen order (cycled);
# rows within a bucket alternate dark/light. First four match the reference file.
BAND_PALETTE = [
    ("FFE2EFDA", "FFF2F8EC", "FF375623"),
    ("FFDDEBF7", "FFEEF6FC", "FF1F4E78"),
    ("FFFCE4D6", "FFFDEEE6", "FF843C0C"),
    ("FFFFF2CC", "FFFFF9E8", "FF806000"),
    ("FFEAE1F2", "FFF4F0F8", "FF5F3B76"),
    ("FFD9F0ED", "FFECF8F6", "FF1F6E68"),
    ("FFFCE4EC", "FFFDF1F5", "FF8C2846"),
    ("FFEDEDED", "FFF6F6F6", "FF44464A"),
]

THIN = Side(style="thin", color=BORDER_GREY)
BORDER = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)


def _fill(argb):
    return PatternFill("solid", fgColor=argb)


def resolve_output_path(cfg, the_date, explicit):
    fname = "Job-Shortlist-{}.xlsx".format(the_date)
    if explicit:
        return os.path.abspath(os.path.expanduser(explicit))
    out_dir = cfg.get("output_dir")
    if not out_dir:
        desktop = os.path.join(os.path.expanduser("~"), "Desktop")
        out_dir = desktop if os.path.isdir(desktop) else os.path.expanduser("~")
    out_dir = os.path.abspath(os.path.expanduser(out_dir))
    os.makedirs(out_dir, exist_ok=True)
    return os.path.join(out_dir, fname)


def order_jobs(jobs):
    bucket_order = {}
    for j in jobs:
        b = j.get("bucket", "")
        if b not in bucket_order:
            bucket_order[b] = len(bucket_order)
    indexed = list(enumerate(jobs))
    indexed.sort(key=lambda t: (bucket_order[t[1].get("bucket", "")], t[0]))
    return [j for _, j in indexed], bucket_order


def build(cfg, output_path):
    name = cfg.get("name", "").strip() or "Me"
    the_date = str(cfg.get("date") or date.today().isoformat())
    jobs = cfg.get("jobs", [])
    if not isinstance(jobs, list):
        raise ValueError("`jobs` must be a list")

    jobs, bucket_order = order_jobs(jobs)
    band_of = {b: BAND_PALETTE[i % len(BAND_PALETTE)] for b, i in bucket_order.items()}

    counts = {b: 0 for b in bucket_order}
    for j in jobs:
        counts[j.get("bucket", "")] = counts.get(j.get("bucket", ""), 0) + 1
    count_bits = [
        "{} ({})".format(b.split()[0] if b.split() else b, counts[b])
        for b in bucket_order
    ]

    wb = Workbook()
    ws = wb.active
    ws.title = "Shortlist"
    ws.sheet_view.showGridLines = False
    last_col = get_column_letter(NCOLS)

    ws.merge_cells("A1:{}1".format(last_col))
    c = ws["A1"]
    c.value = "Job Shortlist — {}".format(name)
    c.font = Font(name="Calibri", size=16, bold=True, color=BANNER_TITLE)
    c.fill = _fill(NAVY)
    c.alignment = Alignment(horizontal="left", vertical="center")
    ws.row_dimensions[1].height = 30

    ws.merge_cells("A2:{}2".format(last_col))
    tip = cfg.get("tip") or "tip: use the Status dropdown to track each one"
    subtitle = "{}  ·  {} roles  ·  {}".format(the_date, len(jobs), tip)
    if count_bits:
        subtitle += "  ·  " + " · ".join(count_bits)
    c = ws["A2"]
    c.value = subtitle
    c.font = Font(name="Calibri", size=10, italic=True, color=BANNER_SUB)
    c.fill = _fill(NAVY)
    c.alignment = Alignment(horizontal="left", vertical="center")
    ws.row_dimensions[2].height = 18

    for idx, col in enumerate(COLUMNS, start=1):
        c = ws.cell(row=3, column=idx, value=col[0])
        c.font = Font(name="Calibri", size=11, bold=True, color=HEADER_TEXT)
        c.fill = _fill(NAVY)
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border = BORDER
    ws.row_dimensions[3].height = 19.5

    first_data_row = 4
    row = first_data_row
    prev_bucket = None
    pos = 0
    for job in jobs:
        bucket = job.get("bucket", "")
        dark_fill, light_fill, band_font = band_of.get(bucket, BAND_PALETTE[0])
        if bucket != prev_bucket:
            pos = 0
            prev_bucket = bucket
        pos += 1
        band_fill = dark_fill if pos % 2 == 1 else light_fill
        for idx, (header, key, width, halign, wrap) in enumerate(COLUMNS, start=1):
            c = ws.cell(row=row, column=idx)
            c.border = BORDER
            c.alignment = Alignment(horizontal=halign, vertical="center", wrap_text=wrap)
            if key == "status":
                c.value = job.get("status") or "To apply"
                c.fill = _fill(STATUS_FILL)
                c.font = Font(name="Calibri", size=10, bold=True, color=STATUS_TEXT)
            elif key == "bucket":
                c.value = bucket
                c.fill = _fill(band_fill)
                c.font = Font(name="Calibri", size=10, bold=True, color=band_font)
            elif key == "link":
                c.fill = _fill(band_fill)
                url = job.get("link")
                if url:
                    c.value = "Open ↗"
                    c.hyperlink = url
                    c.font = Font(size=10, color=LINK_TEXT)
                else:
                    c.value = None
                    c.font = Font(size=10)
            else:
                c.value = job.get(key)
                c.fill = _fill(band_fill)
                c.font = Font(name="Calibri", size=10, color="FF000000")
        ws.row_dimensions[row].height = 15.75
        row += 1

    last_row = row - 1 if jobs else first_data_row

    if jobs:
        formula = '"' + ",".join(STATUS_OPTIONS) + '"'
        dv = DataValidation(type="list", formula1=formula, allow_blank=True)
        dv.add("A{}:A{}".format(first_data_row, last_row))
        ws.add_data_validation(dv)

    ws.freeze_panes = "A4"
    ws.auto_filter.ref = "A3:{}{}".format(last_col, last_row)

    for idx, col in enumerate(COLUMNS, start=1):
        ws.column_dimensions[get_column_letter(idx)].width = col[2]

    wb.save(output_path)
    return output_path, len(jobs), list(bucket_order)


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__ + "\nERROR: missing <input.json>\n")
        return 2
    with open(argv[1], "r", encoding="utf-8") as f:
        cfg = json.load(f)
    the_date = str(cfg.get("date") or date.today().isoformat())
    out_path = resolve_output_path(cfg, the_date, argv[2] if len(argv) > 2 else None)
    saved, n, buckets = build(cfg, out_path)
    print("Wrote {} roles across {} buckets to:\n  {}".format(n, len(buckets), saved))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
```
========================================================================================
````

---

That's the whole thing in one prompt. The search, filtering, and scheduling happen in the chat; the
embedded renderer (written to your task folder during setup) keeps every run's Excel format identical.
Needs Python with `openpyxl` (`pip install openpyxl`).
