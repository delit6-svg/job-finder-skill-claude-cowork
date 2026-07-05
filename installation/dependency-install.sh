#!/usr/bin/env bash
#
# dependency-install.sh — ensure Python is installed, then run the shared
#                         installer (install.py). macOS / Linux.
#
# Thin bootstrapper. Its only job is the one thing a Python script can't do for
# itself: install Python if it's missing (via Homebrew, falling back to a
# python.org link). It then hands off to installation/install.py, which holds all
# the real staging logic and is shared with Windows.
#
# Any arguments (e.g. a task id) are forwarded to install.py.
#
# Usage:
#   bash installation/dependency-install.sh [task-id]
#   task-id  kebab-case task folder name (default: daily-job-search)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_PY="$SCRIPT_DIR/install.py"

# Probe for a working Python >= 3.8.
find_python() {
    for cand in python3 python; do
        if command -v "$cand" >/dev/null 2>&1 &&
           "$cand" -c "import sys; sys.exit(0 if sys.version_info >= (3,8) else 1)" >/dev/null 2>&1; then
            printf '%s' "$cand"
            return 0
        fi
    done
    return 1
}

printf '\033[36m==> Checking for Python (>= 3.8)\033[0m\n'
if PY="$(find_python)"; then
    :
else
    printf '\033[33m    Python 3.8+ not found.\033[0m\n'
    if command -v brew >/dev/null 2>&1; then
        printf '\033[33m    Installing Python via Homebrew...\033[0m\n'
        brew install python || true
    fi
    if ! PY="$(find_python)"; then
        printf '\033[33m    Could not install Python automatically. Install it, then re-run:\033[0m\n'
        printf '      macOS (Homebrew):  brew install python\n'
        printf '      or download from:  https://www.python.org/downloads/macos/\n'
        exit 1
    fi
fi
printf '\033[32m    Using %s\033[0m\n' "$PY"

# Hand off to the shared installer, forwarding an optional task-id.
exec "$PY" "$INSTALL_PY" "$@"
