# Autonomy Loop: Smoke Tests

## Goal
Create smoke tests that verify the repo works end-to-end when cloned fresh and the documented steps are followed with real commands. These prove the README instructions are current, the CI pipeline works, and a new developer (or agent) can get from clone to working infrastructure without hitting broken paths.

## What "smoke" means here
Not unit tests or terraform test -- those already exist (11 pass). A smoke test is a standalone script that:
1. Clones the repo to a temp directory
2. Runs terraform init, validate, fmt-check
3. Runs terraform test (unit + integration)
4. Validates cloud-init syntax + structural checks
5. Checks CI workflow YAML is parseable
6. Verifies every script in scripts/ is executable
7. Prints a PASS/FAIL summary

The script must be able to run in CI (GitHub Actions) as a new gate before terraform plan.

## Design decisions
- `scripts/smoke-test.sh` -- single bash script, no framework, no pip install
- Uses `set -euo pipefail` so any failure aborts
- Reports each gate with [PASS]/[FAIL] and a final summary
- Exits non-zero on any failure (CI-native)
- Can be run locally with `bash scripts/smoke-test.sh`
- Added to CI workflow as `smoke` job (parallel with `validate`)

## Red-before / green-after
- RED-BEFORE: run smoke-test.sh on a repo with a broken cloud-init.yaml (e.g., missing write_files) -- must FAIL
- GREEN-AFTER: run on the clean repo -- must PASS

## Trust tier
T3 (assertions over real commands). The script runs actual terraform/python commands and asserts their exit codes.

## Risks
- Requires terraform installed (CI runner has it via hashicorp/setup-terraform)
- Requires yt-dlp or other tools might not be in CI path -- script skips those gracefully
- terraform init downloads providers -- adds ~30s to CI run
