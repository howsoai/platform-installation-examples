#!/usr/bin/env bash
set -euo pipefail

# Argo Workflows Integration — Add-on
# See argo-workflows/README.md for full documentation.
# Run from the repository root directory.

echo "=== Adding argo-workflows.local.howso.com to /etc/hosts ==="
if ! grep -q 'argo-workflows.local.howso.com' /etc/hosts; then
  echo "127.0.0.1  argo-workflows.local.howso.com" | sudo tee -a /etc/hosts
fi

echo "=== Adding Argo Helm repository ==="
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "=== Installing Argo Workflows ==="
helm install argo-workflows argo/argo-workflows \
  --namespace howso \
  --values argo-workflows/manifests/argo-workflows.yaml \
  --wait

echo "=== Enabling Workflows in Howso Platform ==="
helm upgrade howso-platform \
  oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --values argo-workflows/manifests/howso-platform.yaml \
  --wait --timeout 20m

echo "=== Restarting Argo Workflows pods ==="
kubectl -n howso rollout restart deployment -l app.kubernetes.io/instance=argo-workflows

echo "=== Waiting for Argo Workflows pods ==="
sleep 10
kubectl -n howso wait --for=condition=ready --timeout=120s pod -l app.kubernetes.io/instance=argo-workflows

echo "=== Installation complete ==="
echo "Argo UI: https://argo-workflows.local.howso.com"
echo "Check workflow templates: kubectl get workflowtemplates -n howso"
echo "Next steps: see argo-workflows/README.md#run-the-ui-synthesizer-feature"
