# Project structure

This document explains what each folder and file in the project does.

## `README.md`
Project instructions for the users.

## `installation/`
Installation files required for the initial installation. Each user runs this once.

- **`PROMPT.md`** — Claude Cowork instructions used to create the scheduler and the initial configuration.
- **`dependency-install.ps1`** / **`dependency-install.sh`** — Thin per-OS bootstrappers (Windows / macOS · Linux). Their only job is the one thing a Python script can't do for itself: install Python if it's missing (Windows: winget; macOS: Homebrew; else a python.org link), then hand off to `install.py`, forwarding an optional task-id.
- **`install.py`** — The shared, cross-platform installer with all the real staging logic. It detects the Claude Desktop scheduler root (`~/Claude/Scheduled`, falling back to `~/Documents/claude/Scheduled`, else created), ensures `openpyxl`, and stages the skill into `<schedulerRoot>/<taskId>/` (default `daily-job-search`): `SKILL.md`, `seen-jobs.json` (preserved if it already exists), `.scripts/`, and `build_shortlist.py` extracted from `SKILL.md`'s `RENDERER SCRIPT` block. It only stages files — registering the scheduled task still happens inside Cowork (`create_scheduled_task`, per `SKILL.md` STEP 4).

## `configuration/`
Configuration files that don't change after installation (user config files).

- **`seen-jobs.json`** — Jobs found by the scheduler runs.

## `mutation/`
Files that can change in the future on the user's side after installation.

- **`SKILL.md`** — The scheduler prompt, verbatim.
- **`.scripts/`** — Scheduler scripts.
  - **`dedupe.py`** — Script that validates there are no dupes in the found jobs. The scheduler uses this script to filter out duplicated jobs (jobs that were already found before).
  - **`test.py`** — Test cases for the dedupe.
  - **`_candidates.txt`** — Scratch: all URLs found in the current run, before dedupe. Overwritten each run.
  - **`_new.txt`** — Scratch: the new URLs that survived dedupe in the current run. Overwritten each run.
