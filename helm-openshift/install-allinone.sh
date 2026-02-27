#!/usr/bin/env bash
set -euo pipefail

# Helm OpenShift Installation — Option 1: All-in-One (Built-in Services)
# See helm-openshift/README.md for full documentation.
# Run from the repository root directory.

echo "=== Creating howso namespace ==="
kubectl create namespace howso

echo "=== Applying CRDs ==="
helm template oci://registry.how.so/howso-platform/stable/howso-platform \
  --show-only 'templates/crds/*.yaml' | kubectl apply -f -

echo "=== Installing Howso Platform (built-in services, OpenShift) ==="
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-openshift/manifests/howso-platform-openshift.yaml \
  --wait --timeout 20m

echo "=== Installation complete ==="
echo "Monitor pods: watch kubectl -n howso get po"
echo "Check SCCs: kubectl -n howso get po -o jsonpath='{range .items[*]}{.metadata.name}{\"\\t\"}{.metadata.annotations.openshift\\.io/scc}{\"\\n\"}{end}'"
echo "Next steps: see common/README.md#login-to-the-howso-platform"
