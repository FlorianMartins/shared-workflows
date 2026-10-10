#!/usr/bin/env bash
# =============================================================================
# bootstrap-repo.sh — apply the repository security baseline through the API.
#
#   scripts/bootstrap-repo.sh OWNER/REPO [--check "CI / CI complete"]...
#
# Idempotent: run it on a new repository right after `gh repo create`, and again
# whenever the baseline changes. Needs `gh` authenticated with Administration
# (read/write) on the repository.
#
#   - Dependabot alerts + automated security fixes
#   - secret scanning + push protection (public repositories)
#   - delete head branches on merge, squash merge allowed
#   - default branch protected: no force push, no deletion, required checks
#     (the baseline's own checks + every --check given), admins may bypass
#     so a solo maintainer is never locked out
# =============================================================================
set -euo pipefail

usage() { sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

[[ $# -ge 1 ]] || usage 1
[[ $1 == -h || $1 == --help ]] && usage 0
repo=$1; shift

checks=(
  "security / Secret scanning (gitleaks)"
  "security / Workflow audit (actionlint + zizmor)"
)
while [[ $# -gt 0 ]]; do
  case $1 in
    --check) checks+=("$2"); shift 2 ;;
    --no-baseline-checks) checks=(); shift ;;
    *) echo "unknown argument: $1" >&2; usage 1 ;;
  esac
done

say() { printf '  %-44s %s\n' "$1" "$2"; }

info=$(gh api "repos/${repo}" --jq '[.default_branch, .visibility] | @tsv')
branch=$(cut -f1 <<<"$info")
visibility=$(cut -f2 <<<"$info")
echo "▶ ${repo} (${visibility}, default branch ${branch})"

gh api -X PUT "repos/${repo}/vulnerability-alerts" --silent && say "Dependabot alerts" "enabled"
gh api -X PUT "repos/${repo}/automated-security-fixes" --silent && say "Dependabot security updates" "enabled"

gh api -X PATCH "repos/${repo}" --silent \
  -F delete_branch_on_merge=true -F allow_squash_merge=true \
  && say "delete branch on merge" "enabled"

if [[ $visibility == public ]]; then
  gh api -X PATCH "repos/${repo}" --silent --input - <<'JSON' && say "secret scanning + push protection" "enabled"
{"security_and_analysis": {
  "secret_scanning": {"status": "enabled"},
  "secret_scanning_push_protection": {"status": "enabled"}}}
JSON
else
  say "secret scanning + push protection" "skipped (needs GHAS on private repos)"
fi

contexts=$(printf '%s\n' "${checks[@]}" | python3 -c 'import json,sys; print(json.dumps([l for l in sys.stdin.read().splitlines() if l]))')
protection=$(cat <<JSON
{
  "required_status_checks": {"strict": false, "contexts": ${contexts}},
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
)
if ! err=$(gh api -X PUT "repos/${repo}/branches/${branch}/protection" --silent --input - <<<"$protection" 2>&1); then
  if [[ $visibility != public ]]; then
    say "branch protection" "skipped (private repos need GitHub Pro)"
    exit 0
  fi
  echo "$err" >&2
  exit 1
fi
say "branch protection (${branch})" "no force push, no deletion"
for c in "${checks[@]}"; do say "  required check" "$c"; done
