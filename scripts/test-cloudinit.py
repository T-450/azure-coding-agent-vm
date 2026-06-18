#!/usr/bin/env python3
"""
Validate that the cloud-init template renders correctly with all required
sections. This is an offline test that doesn't need Azure credentials.
"""
import yaml
import re
import sys

ERRORS = []

def check(condition, msg):
    if not condition:
        ERRORS.append(msg)

with open("cloud-init.yaml") as f:
    raw = f.read()

# 1. Basic YAML validity (after Terraform templating)
# The template file may have ${} Terraform expressions that make it invalid YAML.
# We check the structural patterns instead.

# 2. Required sections
check("write_files" in raw, "Missing write_files section")
check("runcmd" in raw, "Missing runcmd section")
check("packages" in raw, "Missing packages section")

# 3. Required installed packages
required_pkgs = ["docker.io", "docker-compose-v2", "nodejs", "git", "curl",
                 "ufw", "fail2ban"]
for pkg in required_pkgs:
    check(f"- {pkg}" in raw, f"Missing package: {pkg}")

# 4. Required systemd services
check("sandbox-coding-agent.Dockerfile" in raw, "Missing sandbox Dockerfile")
check("agent-sandbox-build.service" in raw, "Missing sandbox build service")
check("cloudflare-tunnel.service" in raw, "Missing cloudflare tunnel service")

# 5. Required install commands
check("opencode-ai" in raw, "Missing OpenCode install")
check("earendil-works/pi-coding-agent" in raw, "Missing Pi Coding Agent install")
check("hermes-agent.nousresearch.com/install.sh" in raw, "Missing Hermes Agent install")

# 6. Required scripts
check("# Usage: agent-shell" in raw, "Missing agent-shell script")
check("# Usage: run-opencode" in raw, "Missing run-opencode script")
check("# Usage: run-pi" in raw, "Missing run-pi script")

# 7. Terraform template variables are referenced
check("${admin_username}" in raw, "Missing admin_username template variable")
check("${cloudflare_tunnel_token}" in raw, "Missing cloudflare_tunnel_token template variable")

# 8. Cloudflare tunnel service has the token reference
check("cloudflared tunnel run --token" in raw, "Cloudflare tunnel command missing token reference")

# 9. UFW and SSH hardening
check("ufw default deny incoming" in raw, "Missing UFW default deny")
check("PasswordAuthentication no" in raw, "Missing SSH password disable")
check("PermitRootLogin prohibit-password" in raw, "Missing root login restrict")

# 10. Docker data disk setup
check("mkfs.ext4 /dev/sdc1" in raw, "Missing Docker data disk setup")

# 11. No hardcoded secrets
for secret in ["sk-ant-", "sk-proj-", "ghp_"]:
    check(secret not in raw, f"Hardcoded secret pattern found: {secret}")

# Summary
if ERRORS:
    print(f"FAILED: {len(ERRORS)} validation checks failed")
    for e in ERRORS:
        print(f"  ✗ {e}")
    sys.exit(1)
else:
    print("PASSED: All cloud-init validation checks passed")
    sys.exit(0)
