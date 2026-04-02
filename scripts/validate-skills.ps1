param(
  [switch]$Strict,
  [int]$MinLines = 40
)

$ErrorActionPreference = "Stop"

$root = Get-Location
$skills = Get-ChildItem -Path $root -Recurse -Filter SKILL.md
$manifestPath = Join-Path $root "manifest.json"

if (-not $skills) {
  Write-Error "No SKILL.md files found."
}

if (-not (Test-Path $manifestPath)) {
  Write-Error "manifest.json not found."
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
if (-not ($manifest.PSObject.Properties.Name -contains "license") -or [string]::IsNullOrWhiteSpace([string]$manifest.license)) {
  Write-Error "manifest.json missing required 'license' field."
}

$shortManifestDesc = @()
$manifest.skills.PSObject.Properties | ForEach-Object {
  $key = $_.Name
  $desc = [string]$_.Value.description
  if ($desc.Length -lt 20) {
    $shortManifestDesc += [pscustomobject]@{ Skill = $key; Length = $desc.Length; Description = $desc }
  }
}
if ($shortManifestDesc.Count -gt 0) {
  Write-Host "[FAIL] manifest descriptions too short (<20 chars):" -ForegroundColor Red
  $shortManifestDesc | ForEach-Object {
    Write-Host ("  - {0} ({1}) '{2}'" -f $_.Skill, $_.Length, $_.Description) -ForegroundColor Red
  }
  exit 1
}

$requiredHeadings = @(
  '## Safety Rules',
  '## Quick Reference',
  '## Troubleshooting'
)

$failed = $false
$warnCount = 0

foreach ($file in $skills) {
  $rel = $file.FullName.Replace($root.Path + '\', '')
  $content = Get-Content $file.FullName
  $raw = Get-Content $file.FullName -Raw

  $errors = @()
  $warnings = @()

  if ($content.Count -eq 0 -or -not $content[0].StartsWith('# ')) {
    $errors += "missing top-level title (# ...)"
  }

  foreach ($h in $requiredHeadings) {
    if (-not ($content -contains $h)) {
      $errors += "missing required heading: $h"
    }
  }

  if ($raw -notmatch '```') {
    $errors += "missing fenced code block"
  }

  if ($content.Count -lt $MinLines) {
    $warnings += "short skill doc ($($content.Count) lines) - consider expanding depth"
  }

  if ($raw -notmatch 'health|status|verify|validation|Success criteria') {
    $warnings += "no obvious validation guidance found"
  }

  if ($errors.Count -gt 0) {
    $failed = $true
    Write-Host "[FAIL] $rel" -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "  - $e" -ForegroundColor Red }
  } else {
    Write-Host "[PASS] $rel" -ForegroundColor Green
  }

  if ($warnings.Count -gt 0) {
    $warnCount += $warnings.Count
    foreach ($w in $warnings) { Write-Host "  [WARN] $w" -ForegroundColor Yellow }
  }
}

Write-Host ""
Write-Host "Checked $($skills.Count) skills. Warnings: $warnCount"

if ($failed) {
  exit 1
}

if ($Strict -and $warnCount -gt 0) {
  Write-Error "Strict mode failed due to warnings."
}
