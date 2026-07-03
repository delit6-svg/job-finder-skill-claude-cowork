# Cowork Job-Shortlist Assistant (Israel)

Turn Claude **Cowork** into a recurring job-shortlist assistant for the Israeli market — for **any profession** (IT, teaching, HR, legal, and more). It searches Israeli job boards, filters by employment type and seniority, dedupes against what you've already seen, learns from your feedback, and drops a color-coded Excel file with a **Status** dropdown on your Desktop — on the schedule you choose.

The search, filtering, and scheduling happen **in the chat**: you point it at your **CV** (Claude reads it and figures out what to search for) or just type keywords, answer a few questions, and it schedules itself. The one moving part that used to be inconsistent — building the Excel — is now handled by a small deterministic renderer that's **embedded in the setup prompt** (Claude writes it into your task folder during setup), so every run produces the **exact same format**. It supports full-time, part-time, hourly, **temporary (עבודה זמנית)**, **project/freelance (פרויקט)**, and **one-off/gig (עבודה חד פעמית)** roles.

---

## Automated file install (optional)

Before setting up in the chat, you can stage all of the skill's files into the Claude scheduler root
with the installer — it also checks Python + `openpyxl` for you:

- **Windows:** `powershell -ExecutionPolicy Bypass -File installation\install.ps1`
- **macOS:** `bash installation/install.sh`

It creates `~/Claude/Scheduled/<taskId>/` (default `daily-job-search`) with `SKILL.md`,
`seen-jobs.json` (preserved if it already exists), `.scripts/`, and the extracted `build_shortlist.py`.
It does **not** register the schedule — do that in Cowork below. See `README.md` for details.

## Setup (2 minutes)

1. Open **`mutation/SKILL.md`** and copy the prompt inside the code box.
2. Open Claude **Cowork** and paste it into the chat.
3. Claude asks you a few questions right there in the chat (name, CV or keywords, location, employment types, seniority, delivery, schedule). If you choose CV, you **upload it in the chat** and Claude reads it.
4. Claude writes the embedded renderer (`build_shortlist.py`) into the task folder and registers the task. Done — it now appears in your **Scheduled** sidebar and runs on your chosen schedule.

To change it later, just tell Claude in the chat (e.g. *"make my job search weekdays at 8am"* or *"pause it"*).

> **Why a renderer script:** each scheduled run only gathers jobs and writes a `jobs.json`; the renderer turns that JSON into the styled `.xlsx` the same way every time. That's what keeps the banner, colors, columns, and Status dropdown identical from run to run instead of drifting. The script ships inside `job-search-setup.md`, so there are still just two files.

---

## Examples

- **Teacher:** upload CV *or* keywords `מורה, morah, homeroom teacher`; location `Haifa`; types `Full-time salaried, Temporary`; seniority `any`; daily 9am.
- **Lawyer:** CV; types `Full-time salaried, Project/Freelance`; seniority `mid`; weekdays 8am.
- **HR:** keywords `HR, גיוס, recruiter, HRBP`; types `Full-time salaried`.
- **Gig / one-off:** keywords `הקמת אתר, logo design, translation`; types `Project/Freelance, One-off/Gig`.

---

## What each run produces

- `Job-Shortlist-YYYY-MM-DD.xlsx` on your Desktop — navy banner, subtitle with date + per-bucket counts, per-bucket color bands with light/dark row striping, a **Status** dropdown (To apply / ✅ Sent / 💬 Interviewing / ❌ Didn't apply / 🚫 Rejected / ⏳ No response), and clickable "Open ↗" links.
- A `jobs.json` (the run's data + backup) and a `seen-jobs.json` so you never see the same listing twice.
- Optional: also upload the same file to Google Drive or email it (if you chose that during setup).

The next run reads your Status marks and **soft-ranks** more of what you applied to and less of what you skipped — it never hides options, and it only changes the row order, never the format.

---

## The renderer (embedded in `job-search-setup.md`)

The renderer is a small Python script kept inside the setup prompt; during setup Claude writes it to your task folder as `build_shortlist.py`. It reads a JSON file of jobs and writes the styled `.xlsx`, and needs Python with `openpyxl` (`pip install openpyxl`). You can also run it by hand:

```
python build_shortlist.py jobs.json            # writes Job-Shortlist-<date>.xlsx to your Desktop
python build_shortlist.py jobs.json out.xlsx   # or an explicit output path
```

`jobs.json` shape:

```json
{
  "name": "Daniel Franko",
  "date": "2026-06-24",
  "output_dir": "C:\\Users\\me\\Desktop",
  "jobs": [
    { "status": "To apply", "bucket": "B1 Help Desk", "title": "…",
      "company": "…", "location": "Tel Aviv", "source": "Indeed",
      "tag": "L1 service desk", "exp": "no exp", "link": "https://…" }
  ]
}
```

Only `name`, `bucket`, and `title` are required per the schema; everything else is optional. Buckets are auto-assigned colors from a fixed palette in first-seen order, so any profession's groups render consistently. Given the same `jobs.json`, the output format is identical every time.

---

## Notes & limits

- Scheduled tasks run **while the Cowork app is open**. If it's closed when a task is due, it runs on next launch.
- **Shortlist only** — it reads public listings and never applies, logs in, or submits anything on your behalf.
- Tuned for **Israeli** boards (AllJobs, Drushim, JobMaster, LinkedIn IL, Indeed IL, Glassdoor IL, and sector boards) in Hebrew and English.

## Files in this repo

- `job-search-setup.md` — the prompt you paste into Cowork (the deterministic Excel renderer is embedded inside it).
- `README.md` — this file.
- `LICENSE` — MIT.

## License

MIT — see `LICENSE`.
