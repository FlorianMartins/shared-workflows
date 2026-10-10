#!/usr/bin/env bash
# =============================================================================
# harden-workflows.sh — bring a repository's workflows to the baseline.
#
#   scripts/harden-workflows.sh [REPO_DIR]
#
#   1. pin every action to a commit SHA, version kept in a comment (pinact)
#   2. add `persist-credentials: false` to every actions/checkout
#   3. audit the result (actionlint, zizmor) — fix what remains by hand
#
# Needs: pinact, uv, gh (authenticated: pinact and zizmor query the API).
# =============================================================================
set -euo pipefail

dir=${1:-.}
here=$(cd "$(dirname "$0")" && pwd)
cd "$dir"
shopt -s nullglob
files=(.github/workflows/*.yml .github/workflows/*.yaml)
[[ ${#files[@]} -gt 0 ]] || { echo "no workflow in $(pwd)"; exit 0; }

token=$(gh auth token)
GITHUB_TOKEN=$token pinact run "${files[@]}"
python3 -I "$here/harden_checkout.py" "${files[@]}"

echo "▶ actionlint"
uvx --from "actionlint-py==1.7.12.25" actionlint "${files[@]}" || true
echo "▶ zizmor"
GH_TOKEN=$token uvx "zizmor==1.30.1" --no-progress .github/workflows || true
