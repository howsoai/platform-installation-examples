#!/usr/bin/env bash
set -euo pipefail

# Custom Ingress Certificates — Add-on
# See custom-ingress-cert/README.md for full documentation.
# Run from the repository root directory.

if ! command -v step &>/dev/null; then
  echo "Error: 'step' CLI is required but not found."
  echo "Install from: https://smallstep.com/docs/step-cli/"
  exit 1
fi

echo "=== Generating self-signed ingress certificate ==="
step certificate create local.howso.com tls.crt tls.key \
  --profile self-signed --not-after 8760h --no-password --insecure --subtle \
  --san www.local.howso.com --san management.local.howso.com \
  --san api.local.howso.com --san pypi.local.howso.com \
  --force

echo "=== Creating Kubernetes TLS secret ==="
kubectl -n howso create secret tls platform-custom-ingress-tls \
  --key tls.key --cert tls.crt \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=== Upgrading Howso Platform with custom ingress cert ==="
helm upgrade howso-platform \
  oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values custom-ingress-cert/manifests/howso-platform.yaml \
  --wait --timeout 20m

echo "=== Installation complete ==="
echo "Inspect the certificate: step certificate inspect https://local.howso.com --insecure"
echo "Next steps: see custom-ingress-cert/README.md"
