<#
.SYNOPSIS
    Packages the Job-Shortlist skill into a single hand-to-Cowork .7z archive.

.DESCRIPTION
    Produces dist\job-finder-skill.7z with a flat entry point so Claude Cowork can be
    handed the archive with no prompt: PROMPT.md and the installer scripts sit at the
    archive root, and the rest of the project lives under repo\ where install.py reads it.

    Archive layout:
        PROMPT.md
        dependency-install.ps1
        dependency-install.sh
        install.py
        repo\mutation\SKILL.md
        repo\mutation\.scripts\dedupe.py
        repo\mutation\.scripts\test.py
        repo\configuration\seen-jobs.json   (reset to "[]")

    Requires 7-Zip (7z / 7za on PATH, or the default install location).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File build-archive.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Note($msg) { Write-Host "    $msg" -ForegroundColor DarkGray }
function Write-Warn2($msg){ Write-Host "    ! $msg" -ForegroundColor Yellow }

# --- 1. Resolve repo root ----------------------------------------------------
$RepoRoot    = $PSScriptRoot
$InstallDir  = Join-Path $RepoRoot "installation"
$MutationDir = Join-Path $RepoRoot "mutation"
Write-Step "Repo root: $RepoRoot"

$flatFiles = @("PROMPT.md", "dependency-install.ps1", "dependency-install.sh", "install.py")
foreach ($f in $flatFiles) {
    $p = Join-Path $InstallDir $f
    if (-not (Test-Path $p)) { throw "Missing $p - run this from a clean checkout of the repo." }
}
if (-not (Test-Path (Join-Path $MutationDir "SKILL.md"))) {
    throw "Missing $MutationDir\SKILL.md - run this from a clean checkout of the repo."
}

# --- 2. Locate 7-Zip ---------------------------------------------------------
Write-Step "Locating 7-Zip"
$SevenZip = $null
foreach ($cand in @("7z", "7za")) {
    $cmd = Get-Command $cand -ErrorAction SilentlyContinue
    if ($cmd) { $SevenZip = $cmd.Source; break }
}
if (-not $SevenZip) {
    foreach ($cand in @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")) {
        if ($cand -and (Test-Path $cand)) { $SevenZip = $cand; break }
    }
}
if (-not $SevenZip) {
    Write-Warn2 "7-Zip was not found."
    Write-Host  "    Install it, then re-run this script:" -ForegroundColor Yellow
    Write-Host  "      winget install -e --id 7zip.7zip" -ForegroundColor Yellow
    Write-Host  "      (or download from https://www.7-zip.org/ )" -ForegroundColor Yellow
    exit 1
}
Write-Ok "Using $SevenZip"

# --- 3. Clean temp staging dir ----------------------------------------------
$Stage = Join-Path $env:TEMP ("job-finder-pack-{0}" -f ([guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

try {
    # --- 4. Copy flat-root files ---------------------------------------------
    Write-Step "Staging archive contents"
    foreach ($f in $flatFiles) {
        Copy-Item (Join-Path $InstallDir $f) (Join-Path $Stage $f) -Force
    }
    Write-Ok "PROMPT.md, dependency-install.ps1, dependency-install.sh, install.py"

    # --- 5. Build repo/ payload ----------------------------------------------
    $RepoStage = Join-Path $Stage "repo"
    $MutStage  = Join-Path $RepoStage "mutation"
    $ScrStage  = Join-Path $MutStage ".scripts"
    $CfgStage  = Join-Path $RepoStage "configuration"
    New-Item -ItemType Directory -Force -Path $ScrStage, $CfgStage | Out-Null

    Copy-Item (Join-Path $MutationDir "SKILL.md") (Join-Path $MutStage "SKILL.md") -Force
    Write-Ok "repo\mutation\SKILL.md"

    $ScrSrc = Join-Path $MutationDir ".scripts"
    $exclude = @("_candidates.txt", "_new.txt")
    Get-ChildItem -Path $ScrSrc -File | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $ScrStage $_.Name) -Force
    }
    Write-Ok "repo\mutation\.scripts\ (dedupe.py, test.py)"

    # Fresh users start with an empty dedupe history, not this repo's populated one.
    [System.IO.File]::WriteAllText((Join-Path $CfgStage "seen-jobs.json"), "[]")
    Write-Ok "repo\configuration\seen-jobs.json (empty)"

    # --- 6. Compress ----------------------------------------------------------
    Write-Step "Compressing to .7z"
    $DistDir = Join-Path $RepoRoot "dist"
    New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
    $OutFile = Join-Path $DistDir "job-finder-skill.7z"
    if (Test-Path $OutFile) { Remove-Item $OutFile -Force }  # avoid appending to a stale archive

    # Archive the staged tree's CONTENTS (not the temp folder itself).
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $SevenZip a -t7z -mx=9 "$OutFile" "$Stage\*" | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0 -or -not (Test-Path $OutFile)) {
        throw "7-Zip failed to create the archive (exit $code)."
    }
    Write-Ok "dist\job-finder-skill.7z"
} finally {
    Remove-Item $Stage -Recurse -Force -ErrorAction SilentlyContinue
}

# --- 7. Summary --------------------------------------------------------------
$sizeKb = [math]::Round((Get-Item $OutFile).Length / 1KB, 1)
Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "  Archive : $OutFile  ($sizeKb KB)"
Write-Host ""
Write-Host "  Hand this .7z to Claude Cowork with no prompt; it reads PROMPT.md at the root,"
Write-Host "  runs the dependency-install bootstrapper, and follows the staged SKILL.md."
