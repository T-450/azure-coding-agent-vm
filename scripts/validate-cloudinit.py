#!/usr/bin/env python3
"""Validate cloud-init YAML syntax."""
import yaml
import sys

with open("cloud-init.yaml") as f:
    yaml.safe_load(f)

print("cloud-init.yaml: valid YAML")
sys.exit(0)
