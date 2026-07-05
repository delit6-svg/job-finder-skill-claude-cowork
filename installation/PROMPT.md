# Job-Shortlist skill — automated install for Claude Cowork

**You are Claude Cowork and you have just been handed this skill bundle. Follow this
file top to bottom. Run the INSTALL section FULLY AUTOMATICALLY — do NOT ask me any
questions, and do NOT stop for confirmation, until you reach CONFIGURE.**

**Executing commands:** whenever a step below needs a command run, run it YOURSELF via
computer use — pick the "Try via computer use" path automatically and proceed. Never ask
me how the install step should be handled or which method to use; just do it.

## What this is

A recurring job-shortlist assistant for the Israeli job market. Installing it stages a
small skill into the Claude scheduler folder and registers a scheduled task that drops a
color-coded Excel shortlist (`Job-Shortlist-YYYY-MM-DD.xlsx`) on the schedule I choose.

## INSTALL — do this now, automatically, with no questions

The installer scripts sit in this same folder, right next to this `PROMPT.md`. The rest
of the skill lives under `repo/`. The installer reads from `repo/` on its own — you do
not need to touch it.

1. If you are still looking at the `.7z` file, extract it first and work from the
   extracted folder (everything below is relative to it).
2. Run the bootstrapper for this machine's operating system from this folder, yourself
   via computer use (do not ask me how — just run it). Use the default task id
   `daily-job-search` (pass no task-id argument):
   - **Windows:** `powershell -ExecutionPolicy Bypass -File dependency-install.ps1`
   - **macOS / Linux:** `bash dependency-install.sh`

   It installs Python if missing, ensures `openpyxl`, and stages the skill into the
   Claude scheduler folder at `<scheduler>/daily-job-search/` (`SKILL.md`,
   `build_shortlist.py`, `.scripts/`, and `seen-jobs.json`). This step is mechanical —
   run it to completion without pausing for input.
3. Confirm the installer printed `Done.` and that
   `<scheduler>/daily-job-search/build_shortlist.py` now exists. If it failed, fix the
   reported problem (e.g. install Python, or extract the archive) and run it again —
   still without asking me.

## CONFIGURE — only after INSTALL succeeded, now talk to me

The skill is now staged under the task id **`daily-job-search`**. Open the staged setup
prompt at `<scheduler>/daily-job-search/SKILL.md` and follow its STEP 1 through STEP 4 to
configure and register the scheduled task.

- Reuse the existing `daily-job-search` folder and task id — the files are ALREADY
  staged there, so do NOT re-stage them and do NOT ask me to pick a new task id.
- This is the point where you ask me how the job search should be configured: my name,
  whether to read my CV or use typed keywords, my location, which employment types to
  include, seniority, delivery (Desktop / Drive / email), and the schedule. Ask a few at
  a time using the in-chat question UI.
- **Location** must be asked as a choice of exactly these options — do not use free-text
  cities: **North**, **Center**, **South**, **All**.
- **CV handling:** never automatically send, upload, attach, or re-transmit my CV
  anywhere. If I choose the CV option, read it ONCE now to derive Hebrew + English search
  keywords and **bake those keywords directly into the scheduled task prompt** — the
  scheduled runs must run from the baked-in keywords and must never carry, open, or send
  the CV file.
- When I've answered, register the task with `create_scheduled_task` under the id
  `daily-job-search`.

**In short: install silently and automatically, then ask me only the questions needed to
configure what jobs to find.**
