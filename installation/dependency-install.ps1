<#
.SYNOPSIS
    Ensures Python is installed, then runs the shared installer (install.py).

.DESCRIPTION
    Thin bootstrapper for Windows. Its only job is the one thing a Python script
    can't do for itself: install Python if it's missing (via winget, falling back
    to a python.org link). It then hands off to installation\install.py, which
    holds all the real staging logic and is shared with macOS/Linux.

    Any extra arguments (e.g. -TaskId my-search) are forwarded to install.py.

.PARAMETER TaskId
    Kebab-case task folder name under the scheduler root. Default: daily-job-search.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File installation\dependency-install.ps1
    powershell -ExecutionPolicy Bypass -File installation\dependency-install.ps1 -TaskId my-search
#>
[CmdletBinding()]
param(
    [string]$TaskId
)

$ErrorActionPreference = "Stop"

# Probe for a working Python >= 3.8. Returns @{ Exe; Base } or $null.
function Find-Python {
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
            if ($LASTEXITCODE -eq 0) { return @{ Exe = $p.exe; Base = $p.base } }
        } catch { } finally { $ErrorActionPreference = $prev }
    }
    return $null
}

$InstallPy = Join-Path $PSScriptRoot "install.py"

Write-Host "==> Checking for Python (>= 3.8)" -ForegroundColor Cyan
$py = Find-Python
if (-not $py) {
    Write-Host "    Python 3.8+ not found." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "    Installing Python via winget..." -ForegroundColor Yellow
        winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
        $py = Find-Python
    }
    if (-not $py) {
        Write-Host "    Could not install Python automatically." -ForegroundColor Yellow
        Write-Host "    Install it, then re-run this script:" -ForegroundColor Yellow
        Write-Host "      winget install -e --id Python.Python.3.12" -ForegroundColor Yellow
        Write-Host "      (or download from https://www.python.org/downloads/windows/ )" -ForegroundColor Yellow
        Write-Host "    If you just installed it, reopen the terminal so PATH updates, then re-run." -ForegroundColor Yellow
        exit 1
    }
}
Write-Host "    Using $($py.Exe) $($py.Base -join ' ')" -ForegroundColor Green

# Hand off to the shared installer, translating -TaskId into install.py's --task-id.
$PyArgs = @($InstallPy)
if ($TaskId) { $PyArgs += @("--task-id", $TaskId) }
& $py.Exe @($py.Base) @PyArgs
exit $LASTEXITCODE
