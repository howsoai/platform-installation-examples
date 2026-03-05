#!/usr/bin/env bash
set -euo pipefail

# KOTS Air-gap Existing Cluster Installation
# See kots-existing-cluster-airgap/README.md for full documentation.
# Run from the repository root directory.
# Requires: KOTS_LICENSE_FILE, AIRGAP_BUNDLE, KOTSADM_BUNDLE

if [[ -z "${KOTS_LICENSE_FILE:-}" ]]; then
  echo "Error: KOTS_LICENSE_FILE not set"
  exit 1
fi
if [[ -z "${AIRGAP_BUNDLE:-}" ]]; then
  echo "Error: AIRGAP_BUNDLE not set"
  exit 1
fi
if [[ -z "${KOTSADM_BUNDLE:-}" ]]; then
  echo "Error: KOTSADM_BUNDLE not set"
  exit 1
fi

if [[ ! -f "$KOTS_LICENSE_FILE" ]]; then
  echo "Error: File not found: $KOTS_LICENSE_FILE"
  exit 1
fi
if [[ ! -f "$AIRGAP_BUNDLE" ]]; then
  echo "Error: File not found: $AIRGAP_BUNDLE"
  exit 1
fi
if [[ ! -f "$KOTSADM_BUNDLE" ]]; then
  echo "Error: File not found: $KOTSADM_BUNDLE"
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

echo "=== Checking local registry connectivity ==="
if ! curl -sf http://registry-localhost:5000/v2/_catalog > /dev/null; then
  echo "Error: Cannot reach local registry at registry-localhost:5000"
  echo "Ensure k3d cluster was created with registry and registry-localhost is in /etc/hosts"
  exit 1
fi

echo "=== Pushing kotsadm images to local registry ==="
kubectl kots admin-console push-images "$KOTSADM_BUNDLE" registry-localhost:5000/howso \
  --registry-username reguser --registry-password pw --namespace howso \
  --skip-registry-check

echo "=== Installing Howso Platform with KOTS (air-gap) ==="
kubectl kots install howso-platform --skip-preflights \
  --namespace howso --no-port-forward \
  --registry-username reguser --registry-password pw \
  --kotsadm-registry registry-localhost:5000 --skip-registry-check \
  --kotsadm-namespace howso --airgap-bundle "$AIRGAP_BUNDLE" \
  --license-file "$KOTS_LICENSE_FILE" \
  --shared-password kotspw --wait-duration 20m \
  --config-values kots-existing-cluster-airgap/manifests/kots-howso-platform.yaml

echo "=== Installation complete ==="
echo "Monitor pods: watch kubectl -n howso get po"
echo "KOTS admin: kubectl kots admin-console -n howso (password: kotspw)"
echo "Next steps: see common/README.md#login-to-the-howso-platform"
