#!/usr/bin/env bash
set -euo pipefail

# Helm Air-gap Installation — Option 1: All-in-One (Built-in Services)
# See helm-airgap/README.md for full documentation.
# Run from the repository root directory.
#
# Prerequisites:
#   - kots CLI installed (https://kots.io/kots-cli/)
#   - Air-gap bundle downloaded to ~/2024.4.0.airgap (adjust AIRGAP_BUNDLE below)
#   - registry-localhost in /etc/hosts

AIRGAP_BUNDLE="${AIRGAP_BUNDLE:-~/2024.4.0.airgap}"

echo "=== Creating k3d cluster ==="
k3d cluster create --config prereqs/k3d-single-node.yaml

echo "=== Creating howso namespace ==="
kubectl create namespace howso

echo "=== Checking local registry connectivity ==="
curl -s http://registry-localhost:5000/v2/_catalog | jq .

echo "=== Pushing images to local registry ==="
kubectl kots admin-console push-images "$AIRGAP_BUNDLE" registry-localhost:5000 \
  --registry-username reguser --registry-password pw \
  --namespace howso --skip-registry-check

echo "=== Downloading Helm chart ==="
tmp_dir=$(mktemp -d)
cd "$tmp_dir"
helm pull oci://registry.how.so/howso-platform/stable/howso-platform --untar --untardir .
cd -
tar -czvf howso-platform-chart.tar.gz -C "$tmp_dir" .
echo "Chart is in howso-platform-chart.tar.gz"

echo "=== Installing Howso Platform (built-in services) ==="
helm install howso-platform "$tmp_dir/howso-platform" \
  --namespace howso \
  --values helm-airgap/manifests/howso-platform-airgap.yaml \
  --wait --timeout 20m

echo "=== Installation complete ==="
echo "Monitor pods: watch kubectl -n howso get po"
echo "Verify images from local registry: kubectl -n howso get po -oyaml | grep 'image:'"
echo "Next steps: see common/README.md#login-to-the-howso-platform"
