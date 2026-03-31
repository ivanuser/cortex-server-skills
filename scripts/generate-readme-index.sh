#!/usr/bin/env bash
set -euo pipefail

README_PATH="${1:-README.md}"
MANIFEST_PATH="${2:-manifest.json}"

if [[ ! -f "$README_PATH" ]]; then
  echo "Error: README not found at $README_PATH" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "Error: manifest not found at $MANIFEST_PATH" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required. Install jq and retry." >&2
  exit 1
fi

tmp_summary="$(mktemp)"
tmp_index="$(mktemp)"
tmp_readme="$(mktemp)"
cleanup() {
  rm -f "$tmp_summary" "$tmp_index" "$tmp_readme"
}
trap cleanup EXIT

total="$(jq '.skills | length' "$MANIFEST_PATH")"
{
  echo "Total skills: **$total**"
  echo
  echo "Category counts:"
  jq -r '
    .skills
    | keys
    | map(split("/")[0])
    | group_by(.)
    | map({category: .[0], count: length})
    | sort_by(.category)
    | .[]
    | "- `\(.category)`: \(.count)"
  ' "$MANIFEST_PATH"
} > "$tmp_summary"

{
  echo '_Generated from `manifest.json` by `pwsh ./scripts/generate-readme-index.ps1` or `./scripts/generate-readme-index.sh`._'
  echo

  mapfile -t categories < <(jq -r '.skills | keys | map(split("/")[0]) | unique | sort[]' "$MANIFEST_PATH")
  for category in "${categories[@]}"; do
    echo "### $category"
    echo "| Skill | Title | Description |"
    echo "|---|---|---|"
    jq -r --arg cat "$category" '
      .skills
      | to_entries
      | map(select(.key | startswith($cat + "/")))
      | sort_by(.key)
      | .[]
      | [
          ("[" + .key + "](" + .key + "/SKILL.md)"),
          ((.value.title // (.key | split("/")[1])) | tostring),
          ((.value.description // "") | tostring)
        ]
      | map(gsub("\\|"; "\\\\|"))
      | "| " + (join(" | ")) + " |"
    ' "$MANIFEST_PATH"
    echo
  done
} > "$tmp_index"

awk -v summary_file="$tmp_summary" -v index_file="$tmp_index" '
  BEGIN {
    while ((getline line < summary_file) > 0) summary = summary line ORS
    close(summary_file)
    while ((getline line < index_file) > 0) index = index line ORS
    close(index_file)
    in_summary = 0
    in_index = 0
  }
  /<!-- AUTO-SUMMARY-START -->/ {
    print
    printf "%s", summary
    in_summary = 1
    next
  }
  /<!-- AUTO-SUMMARY-END -->/ {
    in_summary = 0
    print
    next
  }
  /<!-- AUTO-INDEX-START -->/ {
    print
    printf "%s", index
    in_index = 1
    next
  }
  /<!-- AUTO-INDEX-END -->/ {
    in_index = 0
    print
    next
  }
  {
    if (!in_summary && !in_index) print
  }
' "$README_PATH" > "$tmp_readme"

mv "$tmp_readme" "$README_PATH"
echo "README updated from manifest: $README_PATH"

