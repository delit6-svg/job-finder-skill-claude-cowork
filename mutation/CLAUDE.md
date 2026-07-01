# Project structure

This document explains what each folder and file in the project does.

## `README.md`
Project instructions for the users.

## `installation/`
Installation files required for the initial installation. Each user runs this once.

- **`PROMPT.md`** — Claude Cowork instructions used to create the scheduler and the initial configuration.

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
