# 🛡️ shared-workflows

**The CI security baseline every one of my repositories runs — written once, pinned everywhere.**

[![Self-test](https://github.com/FlorianMartins/shared-workflows/actions/workflows/self-test.yml/badge.svg)](https://github.com/FlorianMartins/shared-workflows/actions/workflows/self-test.yml)

Born from the audit of [Regent](https://github.com/FlorianMartins/regent): the same gaps showed
up in every repository (actions pinned by mutable tags, git credentials left on disk, no secret
scan, Dependabot alerts off, unprotected `main`). This repository fixes them once.

## What is in it

| Piece | Kind | What it does |
|---|---|---|
| [`security-baseline.yml`](.github/workflows/security-baseline.yml) | reusable workflow | **gitleaks** on the whole history · **actionlint** + **zizmor** on the workflows · **dependency-review** on pull requests (public repos) |
| [`container-scan.yml`](.github/workflows/container-scan.yml) | reusable workflow | build · smoke-run · **Trivy** gate (fixable CRITICAL/HIGH) · Trivy SARIF · **SBOM** (SPDX) |
| [`templates/security.yml`](templates/security.yml) | caller to copy | the 20 lines a repository needs to run the baseline |
| [`scripts/bootstrap-repo.sh`](scripts/bootstrap-repo.sh) | API, idempotent | Dependabot alerts + security fixes, secret scanning + push protection, branch protection with required checks |
| [`scripts/harden-workflows.sh`](scripts/harden-workflows.sh) | local | pins every action by SHA (pinact), removes persisted credentials, audits the result |

Every tool is pinned: actions by commit SHA (version in a comment), binaries by version + SHA-256.
Dependabot bumps this repository; callers pin a tag's SHA and get the bump through their own
Dependabot.

## Use it in a repository

```bash
# 1. the workflow
sed -e "s/__SHA__/$(gh api repos/FlorianMartins/shared-workflows/commits/v1 --jq .sha)/" \
    -e "s/__VERSION__/v1/" templates/security.yml > ../my-repo/.github/workflows/security.yml

# 2. harden what was already there
scripts/harden-workflows.sh ../my-repo

# 3. once the workflow has run on main: settings + required checks
scripts/bootstrap-repo.sh FlorianMartins/my-repo --check "CI / CI complete"
```

The baseline's own checks (`security / Secret scanning (gitleaks)`,
`security / Workflow audit (actionlint + zizmor)`) are required by default; add the repository's
own CI gate with `--check`. Admins can still push directly — the protection stops force pushes,
deletions and red merges, not a solo maintainer.

### Fixtures that look like secrets

Add a `.gitleaks.toml` at the root of the repository — gitleaks picks it up:

```toml
[extend]
useDefault = true

[allowlist]
description = "Fake credentials used as test fixtures"
paths = ['''^tests/fixtures/''']
```

### Container images

```yaml
jobs:
  container:
    uses: FlorianMartins/shared-workflows/.github/workflows/container-scan.yml@<sha> # v1
    permissions:
      contents: read
      security-events: write
    with:
      smoke-command: "--version"
```

## The baseline, in one list

- [x] actions pinned by SHA · binaries pinned by version + SHA-256
- [x] `permissions: contents: read` at the top of every workflow, jobs opt in
- [x] `persist-credentials: false` on every checkout
- [x] no `${{ github.event.* }}` inside `run:` — through `env:` only
- [x] gitleaks on the full history, weekly as well as on every push
- [x] actionlint + zizmor on the workflows
- [x] dependency review on pull requests
- [x] Dependabot: alerts, security updates, version updates with a 7-day cooldown, grouped minor/patch
- [x] secret scanning + push protection
- [x] protected default branch with required checks
- [x] lockfiles (uv.lock, package-lock.json, Cargo.lock…) installed in frozen mode

## License

[MIT](LICENSE)
