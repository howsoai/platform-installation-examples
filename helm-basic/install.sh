#!/usr/bin/env bash
set -euo pipefail

# Helm Online Installation — Built-in Services (All-in-One)
# See helm-basic/README.md for full documentation.
# Run from the repository root directory.

echo "=== Creating k3d cluster ==="
k3d cluster create --config prereqs/k3d-single-node.yaml

echo "=== Waiting for metrics-server ==="
until kubectl -n kube-system get pod -l k8s-app=metrics-server -o name 2>/dev/null | grep -q .; do sleep 2; done
kubectl -n kube-system wait --for=condition=ready --timeout=180s pod -l k8s-app=metrics-server

echo "=== Creating howso namespace ==="
kubectl create namespace howso

echo "=== Installing Howso Platform (built-in services) ==="
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --wait --timeout 20m

echo "=== Installation complete ==="
echo "Monitor pods: watch kubectl -n howso get po"
echo "Next steps: see common/README.md#login-to-the-howso-platform"
