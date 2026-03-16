#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-infra/eks/flagger-nginx-validation/cluster-config.yaml}"

command -v eksctl >/dev/null 2>&1 || { echo "Missing required command: eksctl"; exit 1; }

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Cluster config not found: $CONFIG_FILE"
  exit 1
fi

echo "Deleting EKS cluster using config: $CONFIG_FILE"
eksctl delete cluster -f "$CONFIG_FILE"
