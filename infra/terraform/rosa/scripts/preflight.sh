#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd aws
require_cmd terraform
require_cmd rosa

aws sts get-caller-identity >/dev/null
rosa whoami >/dev/null

echo "Preflight OK: AWS + Terraform + ROSA CLI are ready."
