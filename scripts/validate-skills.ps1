param(
  [switch]$Strict,
  [int]$MinLines = 40
)

$ErrorActionPreference = "Stop"

$root = Get-Location
$skills = Get-ChildItem -Path $root -Recurse -Filter SKILL.md

if (-not $skills) {
  Write-Error "No SKILL.md files found."
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
