#!/usr/bin/env bash
set -euo pipefail

# KOTS Existing Cluster Installation
# See kots-existing-cluster/README.md for full documentation.
# Run from the repository root directory.
# Requires: KOTS_LICENSE_FILE

if [[ -z "${KOTS_LICENSE_FILE:-}" ]]; then
  echo "Error: KOTS_LICENSE_FILE not set"
  exit 1
fi

if [[ ! -f "$KOTS_LICENSE_FILE" ]]; then
  echo "Error: License file not found at: $KOTS_LICENSE_FILE"
  exit 1
fi

if ! kubectl kots version &>/dev/null; then
  echo "Error: 'kubectl kots' plugin not found"
  exit 1
fi

echo "=== Creating k3d cluster ==="
k3d cluster create --config prereqs/k3d-single-node.yaml

echo "=== Waiting for metrics-server ==="
until kubectl -n kube-system get pod -l k8s-app=metrics-server -o name 2>/dev/null | grep -q .; do sleep 2; done
kubectl -n kube-system wait --for=condition=ready --timeout=180s pod -l k8s-app=metrics-server

echo "=== Creating howso namespace ==="
kubectl create namespace howso

echo "=== Installing cert-manager ==="
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

echo "=== Waiting for cert-manager ==="
kubectl -n cert-manager wait --for=condition=ready --timeout=180s pod -l app.kubernetes.io/instance=cert-manager

echo "=== Installing Howso Platform with KOTS ==="
kubectl kots install howso-platform --skip-preflights \
  --namespace howso --no-port-forward \
  --license-file "$KOTS_LICENSE_FILE" \
  --shared-password kotspw --wait-duration 20m \
  --config-values kots-existing-cluster/manifests/kots-howso-platform.yaml

echo "=== Installation complete ==="
echo "Monitor pods: watch kubectl -n howso get po"
echo "KOTS admin: kubectl kots admin-console -n howso (password: kotspw)"
echo "Next steps: see common/README.md#login-to-the-howso-platform"
