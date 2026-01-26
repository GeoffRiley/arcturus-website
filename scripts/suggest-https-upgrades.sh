#!/usr/bin/env bash
set -euo pipefail

IN="${1:-reports/links-legacy-raw.txt}"
OUT="${2:-reports/links-https-suggestions.tsv}"

: >"$OUT"

while IFS= read -r url; do
  case "$url" in
  http://*)
    https_url="https://${url#http://}"
    # Try https first
    if curl -I -L --max-time 15 -s -o /dev/null -w '%{http_code}' "$https_url" | grep -Eq '^(200|301|302|403)$'; then
      printf "%s\t%s\n" "$url" "$https_url" >>"$OUT"
    fi
    ;;
  esac
done <"$IN"

echo "Wrote: $OUT"
