#!/usr/bin/env bash
set -euo pipefail

MAP="${1:-reports/links-https-suggestions.tsv}"
ROOT="${2:-site-legacy}"

# Safety: refuse to run if map is empty
[[ -s "$MAP" ]] || {
  echo "ERROR: mapping file is empty: $MAP"
  exit 1
}

while IFS=$'\t' read -r from to; do
  # Escape for sed
  f_esc=$(printf '%s\n' "$from" | sed 's/[\/&]/\\&/g')
  t_esc=$(printf '%s\n' "$to" | sed 's/[\/&]/\\&/g')

  # Replace in common web files
  find "$ROOT" -type f \( -iname '*.htm' -o -iname '*.html' -o -iname '*.css' \) -print0 |
    xargs -0 sed -i "s/$f_esc/$t_esc/g"
done <"$MAP"

echo "Applied rewrites from: $MAP"
