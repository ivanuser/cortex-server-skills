param(
  [string]$ReadmePath = "README.md",
  [string]$ManifestPath = "manifest.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ReadmePath)) {
  throw "README not found at $ReadmePath"
}
if (-not (Test-Path $ManifestPath)) {
  throw "Manifest not found at $ManifestPath"
}

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$skillProps = $manifest.skills.PSObject.Properties

$entries = foreach ($p in $skillProps) {
  $key = $p.Name
  $value = $p.Value
  $parts = $key.Split('/')
  $category = $parts[0]
  $slug = $parts[1]
  $title = if ($value.PSObject.Properties.Name -contains "title" -and $value.title) { $value.title } else { $slug }
  $desc = if ($value.PSObject.Properties.Name -contains "description" -and $value.description) { [string]$value.description } else { "" }
  [pscustomobject]@{
    Key = $key
    Category = $category
    Slug = $slug
    Title = $title
    Description = $desc
  }
}

$total = $entries.Count
$grouped = $entries | Group-Object Category | Sort-Object Name

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add("Total skills: **$total**")
$summaryLines.Add("")
$summaryLines.Add("Category counts:")
foreach ($g in $grouped) {
  $summaryLines.Add("- ``$($g.Name)``: $($g.Count)")
}
$summary = ($summaryLines -join "`r`n")

$indexLines = New-Object System.Collections.Generic.List[string]
$indexLines.Add("_Generated from ``manifest.json`` by ``pwsh ./scripts/generate-readme-index.ps1``._")
$indexLines.Add("")
foreach ($g in $grouped) {
  $indexLines.Add("### $($g.Name)")
  $indexLines.Add("| Skill | Title | Description |")
  $indexLines.Add("|---|---|---|")
  foreach ($e in ($g.Group | Sort-Object Key)) {
    $link = "[$($e.Key)]($($e.Key)/SKILL.md)"
    $titleSafe = $e.Title.Replace("|", "\|")
    $descSafe = $e.Description.Replace("|", "\|")
    $indexLines.Add("| $link | $titleSafe | $descSafe |")
  }
  $indexLines.Add("")
}
$index = ($indexLines -join "`r`n").TrimEnd()

$readme = Get-Content $ReadmePath -Raw

function Set-MarkedSection {
  param(
    [string]$Text,
    [string]$StartMarker,
    [string]$EndMarker,
    [string]$Body
  )
  $pattern = "(?s)$([regex]::Escape($StartMarker)).*?$([regex]::Escape($EndMarker))"
  $replacement = "$StartMarker`r`n$Body`r`n$EndMarker"
  if ($Text -match $pattern) {
    return [regex]::Replace($Text, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, 1)
  }
  return $Text + "`r`n`r`n$replacement`r`n"
}

$readme = Set-MarkedSection -Text $readme -StartMarker "<!-- AUTO-SUMMARY-START -->" -EndMarker "<!-- AUTO-SUMMARY-END -->" -Body $summary
$readme = Set-MarkedSection -Text $readme -StartMarker "<!-- AUTO-INDEX-START -->" -EndMarker "<!-- AUTO-INDEX-END -->" -Body $index

Set-Content -Path $ReadmePath -Value $readme
Write-Host "README updated from manifest: $ReadmePath"
