<#
.SYNOPSIS
    Installs the Job-Shortlist Cowork skill into the Claude Desktop scheduler root (Windows).

.DESCRIPTION
    Stages the skill's files into <schedulerRoot>/<TaskId>/ so a scheduled Cowork task
    can use them, and verifies that Python + openpyxl are available for the project's
    scripts. It does NOT register the scheduled task itself (that happens inside Cowork
    via create_scheduled_task / SKILL.md STEP 4).

.PARAMETER TaskId
    Kebab-case task folder name under the scheduler root. Default: daily-job-search.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File installation\install.ps1
    powershell -ExecutionPolicy Bypass -File installation\install.ps1 -TaskId daily-job-search
#>
[CmdletBinding()]
param(
    [string]$TaskId = "daily-job-search"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Note($msg) { Write-Host "    $msg" -ForegroundColor DarkGray }
function Write-Warn2($msg){ Write-Host "    ! $msg" -ForegroundColor Yellow }

# Run the detected Python, merging stderr, WITHOUT letting a nonzero exit or a
# line on stderr become a terminating error (PowerShell 5.1 wraps native stderr
# in NativeCommandError, which $ErrorActionPreference='Stop' would otherwise throw
# on). Returns an object with .Code and .Output. Reads optional stdin from -In.
function Invoke-Py {
    param(
        [string]$In,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$PyArgs
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if ($PSBoundParameters.ContainsKey("In")) {
            $out = $In | & $PyExe @PyBase @PyArgs 2>&1 | Out-String
        } else {
            $out = & $PyExe @PyBase @PyArgs 2>&1 | Out-String
        }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    [pscustomobject]@{ Code = $code; Output = $out.Trim() }
}

# --- 1. Resolve repo root (parent of this installation/ folder) --------------
$InstallDir = $PSScriptRoot
$RepoRoot   = Split-Path $InstallDir -Parent
Write-Step "Repo root: $RepoRoot"

$MutationDir = Join-Path $RepoRoot "mutation"
$ConfigDir   = Join-Path $RepoRoot "configuration"
$SkillSrc    = Join-Path $MutationDir "SKILL.md"
$ScriptsSrc  = Join-Path $MutationDir ".scripts"
$SeenSrc     = Join-Path $ConfigDir "seen-jobs.json"

if (-not (Test-Path $SkillSrc)) { throw "Missing $SkillSrc - run this from a clean checkout of the repo." }

# --- 2. Detect scheduler root ------------------------------------------------
Write-Step "Locating the Claude scheduler root"
$candidates = @(
    (Join-Path $HOME "Claude\Scheduled"),
    (Join-Path $HOME "Documents\claude\Scheduled")
)
$SchedRoot = $null
foreach ($c in $candidates) {
    if (Test-Path $c) { $SchedRoot = $c; break }
}
if (-not $SchedRoot) {
    $SchedRoot = $candidates[0]
    New-Item -ItemType Directory -Force -Path $SchedRoot | Out-Null
    Write-Ok "None found - created $SchedRoot"
} else {
    Write-Ok "Using $SchedRoot"
}

# --- 3. Resolve / create the task folder ------------------------------------
$TaskDir = Join-Path $SchedRoot $TaskId
New-Item -ItemType Directory -Force -Path $TaskDir | Out-Null
Write-Step "Task folder: $TaskDir"

# --- 4. Verify Python --------------------------------------------------------
Write-Step "Checking for Python (>= 3.8)"
$PyExe  = $null
$PyBase = @()
$probes = @(
    @{ exe = "py";      base = @("-3") },
    @{ exe = "python";  base = @() },
    @{ exe = "python3"; base = @() }
)
foreach ($p in $probes) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $p.exe @($p.base) -c "import sys; sys.exit(0 if sys.version_info >= (3,8) else 1)" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $PyExe = $p.exe; $PyBase = $p.base }
    } catch { } finally { $ErrorActionPreference = $prev }
    if ($PyExe) { break }
}
if (-not $PyExe) {
    Write-Warn2 "Python 3.8+ was not found."
    Write-Host  "    Install it, then re-run this script:" -ForegroundColor Yellow
    Write-Host  "      winget install -e --id Python.Python.3.12" -ForegroundColor Yellow
    Write-Host  "      (or download from https://www.python.org/downloads/windows/ )" -ForegroundColor Yellow
    exit 1
}
$PyVer = (Invoke-Py -PyArgs @("-c", "import platform; print(platform.python_version())")).Output
Write-Ok "Found Python $PyVer  ($PyExe $($PyBase -join ' '))"

# --- 5. Verify openpyxl ------------------------------------------------------
Write-Step "Checking for openpyxl"
if ((Invoke-Py -PyArgs @("-c", "import openpyxl")).Code -eq 0) {
    Write-Ok "openpyxl present"
} else {
    Write-Warn2 "openpyxl not installed - attempting: $PyExe -m pip install --user openpyxl"
    Invoke-Py -PyArgs @("-m", "pip", "install", "--user", "openpyxl") | Out-Null
    if ((Invoke-Py -PyArgs @("-c", "import openpyxl")).Code -eq 0) {
        Write-Ok "openpyxl installed"
    } else {
        Write-Warn2 "Could not install openpyxl automatically. Install it manually before the first run:"
        Write-Host  "      $PyExe -m pip install --user openpyxl" -ForegroundColor Yellow
    }
}

# --- 6. Stage files (flatten, keep .scripts/) --------------------------------
Write-Step "Staging skill files"

Copy-Item $SkillSrc (Join-Path $TaskDir "SKILL.md") -Force
Write-Ok "SKILL.md"

$SeenDst = Join-Path $TaskDir "seen-jobs.json"
if (Test-Path $SeenDst) {
    Write-Note "seen-jobs.json already exists - preserved (your dedupe history is kept)."
} elseif (Test-Path $SeenSrc) {
    Copy-Item $SeenSrc $SeenDst -Force
    Write-Ok "seen-jobs.json"
} else {
    [System.IO.File]::WriteAllText($SeenDst, "[]")
    Write-Ok "seen-jobs.json (initialized empty)"
}

$ScriptsDst = Join-Path $TaskDir ".scripts"
if (Test-Path $ScriptsSrc) {
    New-Item -ItemType Directory -Force -Path $ScriptsDst | Out-Null
    $exclude = @("_candidates.txt", "_new.txt")
    Get-ChildItem -Path $ScriptsSrc -File | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $ScriptsDst $_.Name) -Force
    }
    # Drop any stale bytecode cache we may have copied in the past
    $pyc = Join-Path $ScriptsDst "__pycache__"
    if (Test-Path $pyc) { Remove-Item $pyc -Recurse -Force }
    Write-Ok ".scripts/ (dedupe.py, test.py)"
}

# --- 7. Extract build_shortlist.py from SKILL.md -----------------------------
Write-Step "Extracting the renderer (build_shortlist.py) from SKILL.md"
$RendererDst = Join-Path $TaskDir "build_shortlist.py"
$extractor = @'
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
print("ok")
'@
$extract = Invoke-Py -In $extractor -PyArgs @("-", $SkillSrc, $RendererDst)
if ($extract.Code -ne 0 -or -not (Test-Path $RendererDst)) {
    throw "Failed to extract build_shortlist.py from SKILL.md`n$($extract.Output)"
}
Write-Ok "build_shortlist.py"

# --- 8. Smoke tests (non-fatal) ----------------------------------------------
Write-Step "Running smoke tests"
$dedupe = Join-Path $ScriptsDst "dedupe.py"
if (Test-Path $dedupe) {
    $r = Invoke-Py -PyArgs @($dedupe, "selftest")
    if ($r.Code -eq 0) { Write-Ok "dedupe.py selftest: $($r.Output)" }
    else { Write-Warn2 "dedupe.py selftest failed: $($r.Output)" }
}

$tmpJson = Join-Path $env:TEMP ("shortlist-smoke-{0}.json" -f ([guid]::NewGuid().ToString('N')))
$tmpXlsx = Join-Path $env:TEMP ("shortlist-smoke-{0}.xlsx" -f ([guid]::NewGuid().ToString('N')))
$sample = @'
{ "name": "Install Smoke Test", "date": "2026-07-03",
  "jobs": [ { "bucket": "B1 Test", "title": "Sample role", "company": "ACME",
              "location": "Tel Aviv", "source": "Test", "link": "https://example.com" } ] }
'@
# Write UTF-8 WITHOUT a BOM (Set-Content -Encoding UTF8 adds one in PS 5.1, which
# the renderer rejects); real runs emit jobs.json without a BOM too.
[System.IO.File]::WriteAllText($tmpJson, $sample)
$smoke = Invoke-Py -PyArgs @($RendererDst, $tmpJson, $tmpXlsx)
if ($smoke.Code -eq 0 -and (Test-Path $tmpXlsx)) { Write-Ok "build_shortlist.py rendered a test .xlsx" }
else { Write-Warn2 "build_shortlist.py smoke test did not produce an .xlsx (check openpyxl)" }
Remove-Item $tmpJson, $tmpXlsx -ErrorAction SilentlyContinue

# --- 9. Summary --------------------------------------------------------------
Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  Scheduler root : $SchedRoot"
Write-Host "  Task folder    : $TaskDir"
Write-Host "  Python         : $PyExe $($PyBase -join ' ')  (v$PyVer)"
Write-Host ""
Write-Host "  Next: open Claude Cowork and paste mutation/SKILL.md to register the schedule"
Write-Host "        (create_scheduled_task). This installer only staged the files above."
