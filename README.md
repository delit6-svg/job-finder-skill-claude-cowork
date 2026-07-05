# Israel Job-Shortlist — Claude Cowork skill

A recurring **job-shortlist assistant** for the Israeli market (any profession). On your chosen
schedule it searches Israeli boards (Hebrew + English), hard-filters by employment type and
seniority, dedupes against listings you've already seen, soft-ranks by your own feedback, and drops
a color-coded `Job-Shortlist-YYYY-MM-DD.xlsx` (with a **Status** dropdown) on your Desktop.

This is a **Claude Cowork skill**, not a standalone app: the behavior lives in prompt text
(`mutation/SKILL.md`) plus small Python helpers. A deterministic renderer (`build_shortlist.py`,
embedded in `SKILL.md`) keeps every run's Excel format identical.

## Install

The installer stages the skill into the Claude Desktop **scheduler root** and makes sure Python
(with `openpyxl`) is available for the helper scripts. It does **not** register the schedule — that
last step happens inside Cowork.

Each OS has a thin bootstrapper that installs Python if it's missing, then runs the shared
cross-platform installer (`installation/install.py`).

**Windows** (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File installation\dependency-install.ps1
```

**macOS** (Terminal):

```bash
bash installation/dependency-install.sh
```

Optional: pass a task-id to name the task folder (default `daily-job-search`):
`dependency-install.ps1 -TaskId my-search` / `dependency-install.sh my-search`.

What it does:

1. Installs Python ≥ 3.8 if it's missing (Windows: winget; macOS: Homebrew), falling back to a
   download link if it can't.
2. Finds the scheduler root — `~/Claude/Scheduled`, else `~/Documents/claude/Scheduled`, else creates
   `~/Claude/Scheduled`.
3. Installs `openpyxl` if missing.
4. Stages `<schedulerRoot>/<taskId>/` with `SKILL.md`, `seen-jobs.json` (kept if it already exists,
   so your dedupe history survives re-installs), `.scripts/`, and `build_shortlist.py`.
5. Runs quick smoke tests (`dedupe.py selftest` and a sample render).

## Finish setup in Cowork

Open Claude **Cowork** and paste the prompt in `mutation/SKILL.md`. Claude asks a few questions
(name, CV or keywords, location, employment types, seniority, delivery, schedule), then registers the
scheduled task. To change it later, just tell Claude in the chat (e.g. *"make it weekdays at 8am"* or
*"pause it"*).

## Notes & limits

- Scheduled tasks run **while Cowork is open**; if it's closed when due, they run on next launch.
- **Shortlist only** — reads public listings; never applies, logs in, or submits anything.
- Tuned for **Israeli** boards (AllJobs, Drushim, JobMaster, LinkedIn IL, Indeed IL, Glassdoor IL,
  and sector boards) in Hebrew and English.

## License

MIT.
