#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-infra/eks/flagger-nginx-validation/cluster-config.yaml}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1"; exit 1; }
}

require_cmd aws
require_cmd kubectl
require_cmd eksctl

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Cluster config not found: $CONFIG_FILE"
  echo "Copy infra/eks/flagger-nginx-validation/cluster-config.example.yaml to cluster-config.yaml and adjust values."
  exit 1
fi

cluster_name="$(awk '/^metadata:/{f=1;next} f && /name:/{print $2; exit}' "$CONFIG_FILE")"
region="$(awk '/^metadata:/{f=1;next} f && /region:/{print $2; exit}' "$CONFIG_FILE")"

if [[ -z "$cluster_name" || -z "$region" ]]; then
  echo "Could not parse cluster name/region from config"
  exit 1
fi

echo "Creating EKS cluster '$cluster_name' in region '$region'..."
eksctl create cluster -f "$CONFIG_FILE"

echo "Updating kubeconfig..."
aws eks update-kubeconfig --name "$cluster_name" --region "$region"

echo "Cluster ready. Current context:"
kubectl config current-context
kubectl get nodes -o wide
