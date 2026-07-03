#!/usr/bin/env bash
#
# install.sh — install the Job-Shortlist Cowork skill into the Claude Desktop
#              scheduler root (macOS / Linux).
#
# Stages the skill's files into <schedulerRoot>/<taskId>/ so a scheduled Cowork
# task can use them, and verifies that Python + openpyxl are available for the
# project's scripts. It does NOT register the scheduled task itself (that happens
# inside Cowork via create_scheduled_task / SKILL.md STEP 4).
#
# Usage:
#   bash installation/install.sh [taskId]
#   taskId  kebab-case task folder name (default: daily-job-search)

set -euo pipefail

TASK_ID="${1:-daily-job-search}"

cyan()   { printf '\033[36m==> %s\033[0m\n' "$1"; }
green()  { printf '\033[32m    %s\033[0m\n' "$1"; }
gray()   { printf '\033[90m    %s\033[0m\n' "$1"; }
yellow() { printf '\033[33m    ! %s\033[0m\n' "$1"; }
die()    { printf '\033[31mERROR: %s\033[0m\n' "$1" >&2; exit 1; }

# --- 1. Resolve repo root (parent of this installation/ folder) --------------
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$INSTALL_DIR/.." && pwd)"
cyan "Repo root: $REPO_ROOT"

MUTATION_DIR="$REPO_ROOT/mutation"
CONFIG_DIR="$REPO_ROOT/configuration"
SKILL_SRC="$MUTATION_DIR/SKILL.md"
SCRIPTS_SRC="$MUTATION_DIR/.scripts"
SEEN_SRC="$CONFIG_DIR/seen-jobs.json"

[ -f "$SKILL_SRC" ] || die "Missing $SKILL_SRC — run this from a clean checkout of the repo."

# --- 2. Detect scheduler root ------------------------------------------------
cyan "Locating the Claude scheduler root"
CANDIDATES=("$HOME/Claude/Scheduled" "$HOME/Documents/claude/Scheduled")
SCHED_ROOT=""
for c in "${CANDIDATES[@]}"; do
    if [ -d "$c" ]; then SCHED_ROOT="$c"; break; fi
done
if [ -z "$SCHED_ROOT" ]; then
    SCHED_ROOT="${CANDIDATES[0]}"
    mkdir -p "$SCHED_ROOT"
    green "None found — created $SCHED_ROOT"
else
    green "Using $SCHED_ROOT"
fi

# --- 3. Resolve / create the task folder ------------------------------------
TASK_DIR="$SCHED_ROOT/$TASK_ID"
mkdir -p "$TASK_DIR"
cyan "Task folder: $TASK_DIR"

# --- 4. Verify Python --------------------------------------------------------
cyan "Checking for Python (>= 3.8)"
PY=""
for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1; then
        if "$cand" -c "import sys; sys.exit(0 if sys.version_info >= (3,8) else 1)" >/dev/null 2>&1; then
            PY="$cand"; break
        fi
    fi
done
if [ -z "$PY" ]; then
    yellow "Python 3.8+ was not found."
    printf '    Install it, then re-run this script:\n'
    printf '      macOS (Homebrew):  brew install python\n'
    printf '      or download from:  https://www.python.org/downloads/macos/\n'
    exit 1
fi
PY_VER="$("$PY" -c 'import platform; print(platform.python_version())')"
green "Found Python $PY_VER  ($PY)"

# --- 5. Verify openpyxl ------------------------------------------------------
cyan "Checking for openpyxl"
if "$PY" -c "import openpyxl" >/dev/null 2>&1; then
    green "openpyxl present"
else
    yellow "openpyxl not installed — attempting: $PY -m pip install --user openpyxl"
    if "$PY" -m pip install --user openpyxl >/dev/null 2>&1 && "$PY" -c "import openpyxl" >/dev/null 2>&1; then
        green "openpyxl installed"
    else
        yellow "Could not install openpyxl automatically. Install it before the first run:"
        printf '      %s -m pip install --user openpyxl\n' "$PY"
    fi
fi

# --- 6. Stage files (flatten, keep .scripts/) --------------------------------
cyan "Staging skill files"

cp -f "$SKILL_SRC" "$TASK_DIR/SKILL.md"
green "SKILL.md"

SEEN_DST="$TASK_DIR/seen-jobs.json"
if [ -f "$SEEN_DST" ]; then
    gray "seen-jobs.json already exists — preserved (your dedupe history is kept)."
elif [ -f "$SEEN_SRC" ]; then
    cp -f "$SEEN_SRC" "$SEEN_DST"
    green "seen-jobs.json"
else
    printf '[]' > "$SEEN_DST"
    green "seen-jobs.json (initialized empty)"
fi

if [ -d "$SCRIPTS_SRC" ]; then
    SCRIPTS_DST="$TASK_DIR/.scripts"
    mkdir -p "$SCRIPTS_DST"
    for f in "$SCRIPTS_SRC"/*; do
        base="$(basename "$f")"
        case "$base" in
            _candidates.txt|_new.txt|__pycache__) continue ;;
        esac
        [ -f "$f" ] && cp -f "$f" "$SCRIPTS_DST/$base"
    done
    rm -rf "$SCRIPTS_DST/__pycache__"
    green ".scripts/ (dedupe.py, test.py)"
fi

# --- 7. Extract build_shortlist.py from SKILL.md -----------------------------
cyan "Extracting the renderer (build_shortlist.py) from SKILL.md"
RENDERER_DST="$TASK_DIR/build_shortlist.py"
"$PY" - "$SKILL_SRC" "$RENDERER_DST" <<'PYEOF'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
i = src.find("RENDERER SCRIPT")
if i == -1:
    sys.exit("RENDERER SCRIPT marker not found in SKILL.md")
m = re.search(r"```python\r?\n(.*?)\r?\n```", src[i:], re.S)
if not m:
    sys.exit("python code block not found after RENDERER SCRIPT marker")
with open(sys.argv[2], "w", encoding="utf-8", newline="\n") as f:
    f.write(m.group(1) + "\n")
PYEOF
[ -f "$RENDERER_DST" ] || die "Failed to extract build_shortlist.py from SKILL.md"
green "build_shortlist.py"

# --- 8. Smoke tests (non-fatal) ----------------------------------------------
cyan "Running smoke tests"
if [ -f "$TASK_DIR/.scripts/dedupe.py" ]; then
    if out="$("$PY" "$TASK_DIR/.scripts/dedupe.py" selftest 2>&1)"; then
        green "dedupe.py selftest: $out"
    else
        yellow "dedupe.py selftest failed: $out"
    fi
fi

TMP_JSON="$(mktemp -t shortlist-smoke.XXXXXX)"
TMP_XLSX="${TMP_JSON}.xlsx"
cat > "$TMP_JSON" <<'JSONEOF'
{ "name": "Install Smoke Test", "date": "2026-07-03",
  "jobs": [ { "bucket": "B1 Test", "title": "Sample role", "company": "ACME",
              "location": "Tel Aviv", "source": "Test", "link": "https://example.com" } ] }
JSONEOF
if "$PY" "$RENDERER_DST" "$TMP_JSON" "$TMP_XLSX" >/dev/null 2>&1 && [ -f "$TMP_XLSX" ]; then
    green "build_shortlist.py rendered a test .xlsx"
else
    yellow "build_shortlist.py smoke test did not produce an .xlsx (check openpyxl)"
fi
rm -f "$TMP_JSON" "$TMP_XLSX"

# --- 9. Summary --------------------------------------------------------------
printf '\n'
green "Done."
printf '  Scheduler root : %s\n' "$SCHED_ROOT"
printf '  Task folder    : %s\n' "$TASK_DIR"
printf '  Python         : %s  (v%s)\n' "$PY" "$PY_VER"
printf '\n'
printf '  Next: open Claude Cowork and paste mutation/SKILL.md to register the schedule\n'
printf '        (create_scheduled_task). This installer only staged the files above.\n'
