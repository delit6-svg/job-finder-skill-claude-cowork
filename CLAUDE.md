# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Goal

Turn Claude **Cowork** into a recurring **job-shortlist assistant for the Israeli market**, for any profession. On a schedule the user picks, it searches Israeli job boards (Hebrew + English), hard-filters by employment type and seniority, dedupes against listings already seen, soft-ranks by the user's own feedback, and drops a color-coded `Job-Shortlist-YYYY-MM-DD.xlsx` (with a Status dropdown) on their Desktop.

## What this repo is

This is **not a runnable application** — it's a **Claude Cowork skill** distributed as prompt text plus two small Python support scripts. The core behavior (searching, filtering, ranking, scheduling) lives in **natural-language prompts**, not code. Changing behavior usually means editing prompt Markdown, not `.py` files.

## Runtime flow

1. **Install (once):** the user pastes the prompt in `mutation/SKILL.md` into Cowork. Claude asks setup questions (name, CV/keywords, location, employment types, seniority, delivery, schedule), reads the CV to derive Hebrew+English keywords, writes the renderer `build_shortlist.py` into the user's task folder, and registers a scheduled task via `create_scheduled_task`.
2. **Each scheduled run** (a self-contained prompt baked in at install — *no memory of the setup chat*): searches boards → hard-filters → dedupes against `seen-jobs.json` → soft-ranks from the user's Status marks in recent `.xlsx` files → writes `jobs.json` → calls `build_shortlist.py` to render the `.xlsx`.

**Key design principle — the deterministic renderer:** runs never hand-build the Excel (it drifts). They emit a `jobs.json` and call a fixed renderer, so every run's format (banner, columns, colors, Status dropdown) is identical. Preserve this separation when editing.

## The renderer lives inside the setup prompt

`build_shortlist.py` does **not** exist as a standalone file in this repo. It's embedded **verbatim** inside `mutation/SKILL.md`, in the `RENDERER SCRIPT` fenced block at the very end, and is copied into the user's task folder at install time. To change the Excel output, **edit that embedded block** — and keep it backward-compatible with existing `jobs.json` files. The `jobs.json` schema (STEP 3) and the column/bucket/palette details are documented in the same file. Requires `openpyxl`; manual run: `py build_shortlist.py jobs.json [out.xlsx]`.

## Project structure

For the full file/folder breakdown, see the imported project-structure doc:

@mutation/CLAUDE.md

## Commands

Run the dedupe tests from `mutation/.scripts/`. Bare `python` hits an unconfigured Microsoft Store alias on this machine — use the `py` launcher (the run prompt itself falls back `python` → `py` → `python3`):

```bash
py test.py              # scenario tests for dedupe.py (exits nonzero on failure)
py dedupe.py selftest   # dedupe.py's inline assertions; prints "OK"
```

## Gotchas

- `installation/PROMPT.md` (the overview) still points readers to a `job-search-setup.md`; that verbatim prompt now lives at `mutation/SKILL.md`, and `README.md` is currently empty. Trust the actual files over these references.
- The scheduled-run prompt is intentionally self-contained (no memory of setup). When editing run behavior, keep everything the run needs baked into that prompt.
