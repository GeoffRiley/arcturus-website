#!/usr/bin/env bash
set -euo pipefail

# --- locate repo root (script can be run from anywhere) ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# --- config ---
SITE_URL="${1:-https://arcturus.geoffandcarole.co.uk/}"
STAMP="${STAMP:-$(date -u +%F)}" # UTC date, override by setting STAMP=...
REPORT_DIR="${REPO_ROOT}/reports/lychee"
FULL_JSON="${REPORT_DIR}/${STAMP}-lychee.json"

BROKEN_TSV="${REPORT_DIR}/${STAMP}-broken.tsv"
BROKEN_UNIQ="${REPORT_DIR}/${STAMP}-broken-unique.txt"
REDIRECT_TSV="${REPORT_DIR}/${STAMP}-redirects.tsv"

# --- sanity checks ---
command -v docker >/dev/null 2>&1 || {
  echo "ERROR: docker not found in PATH"
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq not found (sudo apt install jq)"
  exit 1
}

mkdir -p "${REPORT_DIR}"

echo "Repo root : ${REPO_ROOT}"
echo "Site      : ${SITE_URL}"
echo "Output    : ${FULL_JSON}"

# --- run lychee in docker ---
set +e
docker run --rm \
  -v "${REPO_ROOT}:/out" \
  lycheeverse/lychee \
  --format json \
  --output "/out/reports/lychee/$(basename "${FULL_JSON}")" \
  --accept 200,301,302 \
  --timeout 20 \
  "${SITE_URL}"
LYCHEE_EXIT=$?
set -e

if [[ -f "${FULL_JSON}" ]]; then
  echo "Wrote: ${FULL_JSON}"
else
  echo "ERROR: Expected report file not found: ${FULL_JSON}"
  exit 1
fi

if [[ $LYCHEE_EXIT -ne 0 ]]; then
  echo "NOTE: lychee reported problems (exit code ${LYCHEE_EXIT}). Continuing to post-process."
fi

# Broken links TSV
jq -r '
  .error_map
  | to_entries[]
  | .key as $source
  | .value[]
  | [$source, .url, (.status.code|tostring), .status.text]
  | @tsv
' "${FULL_JSON}" >"${BROKEN_TSV}"

# Unique broken link counts
jq -r '.error_map | to_entries[] | .value[].url' "${FULL_JSON}" |
  sort | uniq -c | sort -nr >"${BROKEN_UNIQ}"

# Redirects TSV (optional but useful)
jq -r '
  .redirect_map
  | to_entries[]
  | .key as $source
  | .value[]
  | [$source, .url, (.status.code|tostring), .status.text]
  | @tsv
' "${FULL_JSON}" >"${REDIRECT_TSV}"

echo "Wrote: ${BROKEN_TSV}"
echo "Wrote: ${BROKEN_UNIQ}"
echo "Wrote: ${REDIRECT_TSV}"

# Optional: propagate lychee exit code for CI later
# exit $LYCHEE_EXIT
exit 0
