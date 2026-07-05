#!/usr/bin/env python3
"""Install the Job-Shortlist Cowork skill into the Claude Desktop scheduler root.

Cross-platform (Windows / macOS / Linux). Stages the skill's files into
<schedulerRoot>/<taskId>/ so a scheduled Cowork task can use them, and makes sure
`openpyxl` is available for the renderer. It does NOT register the scheduled task
itself — that happens inside Cowork via create_scheduled_task (SKILL.md STEP 4).

This script assumes Python is already present (it is what runs it). The per-OS
`dependency-install.ps1` / `dependency-install.sh` bootstrappers install Python if
missing and then hand off here.

Usage:
    python install.py [--task-id daily-job-search]
    python install.py my-search          # task id may also be positional
"""

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

# --- tiny colored/step output (ANSI; harmless if a terminal ignores it) ------
_CYAN, _GREEN, _GRAY, _YELLOW, _RESET = "\033[36m", "\033[32m", "\033[90m", "\033[33m", "\033[0m"


def step(msg):  print(f"{_CYAN}==> {msg}{_RESET}")
def ok(msg):    print(f"{_GREEN}    {msg}{_RESET}")
def note(msg):  print(f"{_GRAY}    {msg}{_RESET}")
def warn(msg):  print(f"{_YELLOW}    ! {msg}{_RESET}")
def die(msg):   sys.exit(f"ERROR: {msg}")


def py_can_import(module):
    """True if `module` imports cleanly under this interpreter."""
    return subprocess.run(
        [sys.executable, "-c", f"import {module}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0


def main():
    parser = argparse.ArgumentParser(description="Stage the Job-Shortlist Cowork skill.")
    parser.add_argument(
        "task_id_pos", nargs="?", metavar="TASK_ID",
        help="Kebab-case task folder name (positional alternative to --task-id).",
    )
    parser.add_argument(
        "--task-id", dest="task_id", default=None,
        help="Kebab-case task folder name under the scheduler root (default: daily-job-search).",
    )
    args = parser.parse_args()
    task_id = args.task_id or args.task_id_pos or "daily-job-search"

    # --- 1. Resolve repo root (holds mutation/ + configuration/) -------------
    # Works in two layouts: the repo checkout (install.py lives in installation/,
    # so the payload is one level up) and the hand-to-Cowork archive (install.py
    # sits at the archive root next to a repo/ subfolder). Pick the first root
    # that actually contains mutation/SKILL.md.
    here = Path(__file__).resolve().parent
    candidates = [here.parent, here / "repo", here]  # repo checkout; archive; flat fallback
    repo_root = next((c for c in candidates if (c / "mutation" / "SKILL.md").is_file()), None)
    if repo_root is None:
        die("Could not locate the skill payload (expected mutation/SKILL.md next to "
            "install.py, in ./repo/, or one level up).")
    step(f"Repo root: {repo_root}")

    mutation_dir = repo_root / "mutation"
    config_dir = repo_root / "configuration"
    skill_src = mutation_dir / "SKILL.md"
    scripts_src = mutation_dir / ".scripts"
    seen_src = config_dir / "seen-jobs.json"

    if not skill_src.is_file():
        die(f"Missing {skill_src} — run this from a clean checkout of the repo.")

    # --- 2. Detect scheduler root --------------------------------------------
    step("Locating the Claude scheduler root")
    home = Path.home()
    candidates = [home / "Claude" / "Scheduled", home / "Documents" / "claude" / "Scheduled"]
    sched_root = next((c for c in candidates if c.is_dir()), None)
    if sched_root is None:
        sched_root = candidates[0]
        sched_root.mkdir(parents=True, exist_ok=True)
        ok(f"None found — created {sched_root}")
    else:
        ok(f"Using {sched_root}")

    # --- 3. Resolve / create the task folder ---------------------------------
    task_dir = sched_root / task_id
    task_dir.mkdir(parents=True, exist_ok=True)
    step(f"Task folder: {task_dir}")

    # --- 4. Report the interpreter -------------------------------------------
    step(f"Using Python {sys.version.split()[0]}  ({sys.executable})")

    # --- 5. Verify openpyxl (non-fatal) --------------------------------------
    step("Checking for openpyxl")
    if py_can_import("openpyxl"):
        ok("openpyxl present")
    else:
        warn(f"openpyxl not installed — attempting: {sys.executable} -m pip install --user openpyxl")
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "--user", "openpyxl"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        if py_can_import("openpyxl"):
            ok("openpyxl installed")
        else:
            warn("Could not install openpyxl automatically. Install it before the first run:")
            print(f"      {sys.executable} -m pip install --user openpyxl")

    # --- 6. Stage files (flatten, keep .scripts/) ----------------------------
    step("Staging skill files")

    shutil.copyfile(skill_src, task_dir / "SKILL.md")
    ok("SKILL.md")

    seen_dst = task_dir / "seen-jobs.json"
    if seen_dst.is_file():
        note("seen-jobs.json already exists — preserved (your dedupe history is kept).")
    elif seen_src.is_file():
        shutil.copyfile(seen_src, seen_dst)
        ok("seen-jobs.json")
    else:
        seen_dst.write_text("[]", encoding="utf-8")
        ok("seen-jobs.json (initialized empty)")

    scripts_dst = task_dir / ".scripts"
    if scripts_src.is_dir():
        scripts_dst.mkdir(parents=True, exist_ok=True)
        exclude = {"_candidates.txt", "_new.txt"}
        for f in scripts_src.iterdir():
            if f.is_file() and f.name not in exclude:
                shutil.copyfile(f, scripts_dst / f.name)
        # Drop any stale bytecode cache we may have copied in the past
        pyc = scripts_dst / "__pycache__"
        if pyc.exists():
            shutil.rmtree(pyc, ignore_errors=True)
        ok(".scripts/ (dedupe.py, test.py)")

    # --- 7. Extract build_shortlist.py from SKILL.md -------------------------
    step("Extracting the renderer (build_shortlist.py) from SKILL.md")
    renderer_dst = task_dir / "build_shortlist.py"
    src = skill_src.read_text(encoding="utf-8")
    i = src.find("RENDERER SCRIPT")
    if i == -1:
        die("RENDERER SCRIPT marker not found in SKILL.md")
    m = re.search(r"```python\r?\n(.*?)\r?\n```", src[i:], re.S)
    if not m:
        die("python code block not found after RENDERER SCRIPT marker")
    # Write with LF newlines and no BOM (real runs / the renderer expect this).
    with open(renderer_dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(m.group(1) + "\n")
    ok("build_shortlist.py")

    # --- 8. Smoke tests (non-fatal) ------------------------------------------
    step("Running smoke tests")
    dedupe = scripts_dst / "dedupe.py"
    if dedupe.is_file():
        r = subprocess.run(
            [sys.executable, str(dedupe), "selftest"],
            capture_output=True, text=True,
        )
        out = (r.stdout + r.stderr).strip()
        if r.returncode == 0:
            ok(f"dedupe.py selftest: {out}")
        else:
            warn(f"dedupe.py selftest failed: {out}")

    tmp = Path(tempfile.gettempdir())
    tmp_json = tmp / f"shortlist-smoke-{uuid.uuid4().hex}.json"
    tmp_xlsx = tmp / f"shortlist-smoke-{uuid.uuid4().hex}.xlsx"
    sample = (
        '{ "name": "Install Smoke Test", "date": "2026-07-03",\n'
        '  "jobs": [ { "bucket": "B1 Test", "title": "Sample role", "company": "ACME",\n'
        '              "location": "Tel Aviv", "source": "Test", "link": "https://example.com" } ] }'
    )
    # Write UTF-8 WITHOUT a BOM (the renderer rejects one); real runs do the same.
    tmp_json.write_text(sample, encoding="utf-8")
    smoke = subprocess.run(
        [sys.executable, str(renderer_dst), str(tmp_json), str(tmp_xlsx)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    if smoke.returncode == 0 and tmp_xlsx.is_file():
        ok("build_shortlist.py rendered a test .xlsx")
    else:
        warn("build_shortlist.py smoke test did not produce an .xlsx (check openpyxl)")
    tmp_json.unlink(missing_ok=True)
    tmp_xlsx.unlink(missing_ok=True)

    # --- 9. Summary ----------------------------------------------------------
    print()
    print(f"{_GREEN}Done.{_RESET}")
    print(f"  Scheduler root : {sched_root}")
    print(f"  Task folder    : {task_dir}")
    print(f"  Python         : {sys.executable}  (v{sys.version.split()[0]})")
    print()
    print("  Next: open Claude Cowork and paste mutation/SKILL.md to register the schedule")
    print("        (create_scheduled_task). This installer only staged the files above.")


if __name__ == "__main__":
    main()
