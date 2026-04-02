#!/usr/bin/env bash
set -euo pipefail

STRICT=0
MIN_LINES=40

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
      shift
      ;;
    --min-lines)
      MIN_LINES="${2:-}"
      if [[ -z "$MIN_LINES" || ! "$MIN_LINES" =~ ^[0-9]+$ ]]; then
        echo "Error: --min-lines requires an integer value." >&2
        exit 2
      fi
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: ./scripts/validate-skills.sh [--strict] [--min-lines N]" >&2
      exit 2
      ;;
  esac
done

if ! command -v find >/dev/null 2>&1; then
  echo "Error: 'find' is required." >&2
  exit 1
fi

if [[ ! -f "manifest.json" ]]; then
  echo "Error: manifest.json not found." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required for manifest checks." >&2
  exit 1
fi

license="$(jq -r '.license // ""' manifest.json)"
if [[ -z "$license" || "$license" == "null" ]]; then
  echo "Error: manifest.json missing required 'license' field." >&2
  exit 1
fi

short_desc_count="$(jq '[.skills | to_entries[] | select((.value.description // "") | length < 20)] | length' manifest.json)"
if [[ "$short_desc_count" != "0" ]]; then
  echo "[FAIL] manifest descriptions too short (<20 chars):" >&2
  jq -r '
    .skills
    | to_entries[]
    | select((.value.description // "") | length < 20)
    | "  - \(.key) (\((.value.description // "") | length)) '\''\(.value.description // "")'\''"
  ' manifest.json >&2
  exit 1
fi

mapfile -t skills < <(find . -type f -name "SKILL.md" | sort)

if [[ ${#skills[@]} -eq 0 ]]; then
  echo "Error: No SKILL.md files found." >&2
  exit 1
fi

failed=0
warn_count=0

for file in "${skills[@]}"; do
  rel="${file#./}"
  errors=()
  warns=()

  first_line="$(head -n 1 "$file" || true)"
  if [[ "$first_line" != \#\ * ]]; then
    errors+=("missing top-level title (# ...)")
  fi

  grep -Fxq "## Safety Rules" "$file" || errors+=("missing required heading: ## Safety Rules")
  grep -Fxq "## Quick Reference" "$file" || errors+=("missing required heading: ## Quick Reference")
  grep -Fxq "## Troubleshooting" "$file" || errors+=("missing required heading: ## Troubleshooting")

  grep -q '```' "$file" || errors+=("missing fenced code block")

  line_count="$(wc -l < "$file" | tr -d ' ')"
  if (( line_count < MIN_LINES )); then
    warns+=("short skill doc (${line_count} lines) - consider expanding depth")
  fi

  if ! grep -Eiq 'health|status|verify|validation|Success criteria' "$file"; then
    warns+=("no obvious validation guidance found")
  fi

  if (( ${#errors[@]} > 0 )); then
    failed=1
    echo "[FAIL] $rel"
    for e in "${errors[@]}"; do
      echo "  - $e"
    done
  else
    echo "[PASS] $rel"
  fi

  if (( ${#warns[@]} > 0 )); then
    warn_count=$((warn_count + ${#warns[@]}))
    for w in "${warns[@]}"; do
      echo "  [WARN] $w"
    done
  fi
done

echo
echo "Checked ${#skills[@]} skills. Warnings: $warn_count"

if (( failed != 0 )); then
  exit 1
fi

if (( STRICT == 1 && warn_count > 0 )); then
  echo "Strict mode failed due to warnings." >&2
  exit 1
fi
