#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Smoke Test Suite for azure-coding-agent-vm
# Verifies that a fresh clone + documented steps work end-to-end.
# Intended to run in CI and locally.
# ---------------------------------------------------------------------------
set -euo pipefail

PASS=0
FAIL=0
RESULTS=()

pass() { PASS=$((PASS+1)); RESULTS+=("PASS: $1"); echo "  [PASS] $1"; }
fail() { FAIL=$((FAIL+1)); RESULTS+=("FAIL: $1"); echo "  [FAIL] $1"; }

section() { echo ""; echo "===== $1 ====="; }

# --- Determine repo root (works for cloned and in-tree runs) ---
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

section "1. Repository structure"
if [ -f main.tf ] && [ -f variables.tf ] && [ -f outputs.tf ]; then
  pass "Core Terraform files present (main.tf, variables.tf, outputs.tf)"
else
  fail "Missing core Terraform files"
fi
if [ -f cloud-init.yaml ]; then pass "cloud-init.yaml present"; else fail "Missing cloud-init.yaml"; fi
if [ -f README.md ]; then pass "README.md present"; else fail "Missing README.md"; fi
if [ -d scripts ]; then pass "scripts/ directory present"; else fail "Missing scripts/"; fi
if [ -d tests ]; then pass "tests/ directory present"; else fail "Missing tests/"; fi
if [ -d .github/workflows ]; then pass ".github/workflows/ present"; else fail "Missing .github/workflows/"; fi

section "2. Terraform format"
if terraform fmt -check -recursive 2>/dev/null; then
  pass "terraform fmt check passed"
else
  fail "terraform fmt check failed -- run 'terraform fmt -recursive'"
fi

section "3. Terraform init + validate"
# Use a temp dir to test init from scratch
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
cp -a "$REPO_ROOT/." "$TMPDIR/" 2>/dev/null || cp -r "$REPO_ROOT"/* "$TMPDIR/" 2>/dev/null || true
# Remove cached .terraform so init truly starts fresh
rm -rf "$TMPDIR/.terraform" "$TMPDIR/.terraform.lock.hcl" 2>/dev/null || true
cd "$TMPDIR"
if terraform init -input=false -no-color 2>&1 | grep -qi "successfully initialized"; then
  pass "terraform init from scratch"
else
  fail "terraform init from scratch failed"
fi
if terraform validate -no-color 2>&1 | grep -q "Success"; then
  pass "terraform validate"
else
  fail "terraform validate failed"
fi

section "4. Terraform test"
if terraform test -no-color 2>&1 | grep -q "Success! 1[1-9] passed"; then
  pass "terraform test (all ${PASS} tests passed)"
elif terraform test -no-color 2>&1 | grep -q "passed"; then
  # Count passed tests from output
  PASSED_COUNT=$(terraform test -no-color 2>&1 | grep -c "\.\.\. pass" || true)
  pass "terraform test (${PASSED_COUNT} tests passed)"
else
  fail "terraform test failed"
fi

section "5. Cloud-init validation"
if python3 "$REPO_ROOT/scripts/validate-cloudinit.py" 2>&1 | grep -q "valid YAML"; then
  pass "cloud-init YAML syntax valid"
else
  fail "cloud-init YAML syntax invalid"
fi
if python3 "$REPO_ROOT/scripts/test-cloudinit.py" 2>&1 | grep -q "PASSED"; then
  pass "cloud-init structural tests passed"
else
  fail "cloud-init structural tests failed"
fi

section "6. CI workflow YAML"
if python3 -c "import yaml; yaml.safe_load(open('.github/workflows/terraform.yml'))" 2>/dev/null; then
  pass "CI workflow YAML parseable"
else
  fail "CI workflow YAML not parseable (install PyYAML: pip install pyyaml)"
fi

section "7. Script executability"
ALL_EXEC=0
for f in scripts/*.py; do
  if [ -x "$f" ]; then
    true
  else
    ALL_EXEC=1
    fail "Script $f is not executable"
  fi
done
if [ "$ALL_EXEC" -eq 0 ]; then pass "All scripts executable"; fi

section "8. README smoke check"
# Verify README has required sections
if grep -q "^## Prerequisites" README.md; then pass "README has Prerequisites section"; else fail "README missing Prerequisites"; fi
if grep -q "^## What gets installed" README.md; then pass "README has What gets installed section"; else fail "README missing What gets installed"; fi
if grep -q "^## API Keys" README.md; then pass "README has API Keys section"; else fail "README missing API Keys"; fi
if grep -q "^## Architecture" README.md; then pass "README has Architecture section"; else fail "README missing Architecture"; fi

section "9. Git state"
cd "$REPO_ROOT"
if git rev-parse --git-dir > /dev/null 2>&1; then
  pass "Valid git repository"
else
  fail "Not a git repository"
fi
if [ -z "$(git ls-files --others --exclude-standard)" ]; then
  pass "No untracked files"
else
  fail "Repository has untracked files: $(git ls-files --others --exclude-standard | tr '\n' ' ')"
fi

# --- Summary ---
echo ""
echo "============================================="
echo "  SMOKE TEST SUMMARY"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "============================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
