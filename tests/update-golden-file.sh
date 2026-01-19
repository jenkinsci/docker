#!/usr/bin/env bash
set -euo pipefail

# This script runs a specified command, captures its output,
# and compares it against a "golden file" representing the expected output.
# If the output differs, the script shows a diff and allows the user to update the golden file.
# If the output matches, it reports that the golden file is up-to-date.
#
# Usage:
#   ./update-golden-file.sh <test-name> <command...>
#
# Arguments:
#   <test-name>    Name of the test, used to determine the golden file path.
#                  The corresponding golden file will be stored as:
#                     golden/<test-name>.txt
#
#   <command...>   Command to run, whose stdout will be compared to the golden file.
#                  This can include arguments, e.g.:
#                     ./update-golden-file.sh expected_tags_latest_lts make tags LATEST_LTS=true
#
# Notes:
#   - Requires Bash 4+ for `BASH_SOURCE` handling.
#   - The script is safe to run from any directory; golden files are always relative to the script's own location.

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <test-name> <command...>"
  echo "Example:"
  echo "  $0 expected_tags_latest_lts make tags LATEST_LTS=true"
  exit 1
fi

name="$1"
shift

# Ensure golden folder is always relative to this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
golden_file="${name}.txt"
golden_path="${script_dir}/golden/${golden_file}"
tmp="$(mktemp)"

echo
echo "Golden file path:"
echo "  ${golden_path}"
echo
echo "Running command:"
echo "  $*"
echo

"$@" > "${tmp}"

action="create"
if [[ -f "${golden_path}" ]]; then
    if diff -u "${golden_path}" "${tmp}" > /dev/null; then
        echo "Golden file '${golden_file}' is already up-to-date."
        rm "${tmp}"
        exit 0
    fi
    echo "Diff against existing golden file '${golden_file}':"
    diff -u "${golden_path}" "${tmp}" || true
    action="update"
else
    echo "Golden file '${golden_file}' does not exist yet."
fi

echo
echo "Golden file to ${action}: '${golden_file}'"
read -rp "Proceed? [y/N] " answer

if [[ "${answer}" =~ ^[Yy]$ ]]; then
    mkdir -p "$(dirname "${golden_path}")"
    mv "${tmp}" "${golden_path}"
    echo "Golden file '${golden_file}' ${action}d."
else
    rm "${tmp}"
    echo "Aborted. Golden file '${golden_file}' unchanged."
fi
