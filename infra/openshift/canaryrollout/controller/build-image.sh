#!/usr/bin/env bash
set -euo pipefail

IMAGE_REPO="${IMAGE_REPO:-ghcr.io/adrianbp/canaryrollout-controller}"
IMAGE_TAG="${IMAGE_TAG:-0.1.0}"
IMAGE="${IMAGE_REPO}:${IMAGE_TAG}"

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"

cd "$ROOT_DIR"

echo "Building image: ${IMAGE}"
docker build -f infra/openshift/canaryrollout/controller/Dockerfile -t "$IMAGE" .

echo "Done. To push:"
echo "  docker push ${IMAGE}"
