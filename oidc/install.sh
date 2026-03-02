#!/usr/bin/env bash
set -euo pipefail

# OIDC (Dex) — Add-on
# See oidc/README.md for full documentation.
# Run from the repository root directory.
#
# Prerequisites:
#   - Howso Platform running (e.g., via helm-basic/install.sh)

echo "=== Adding dex.local.howso.com to /etc/hosts ==="
if ! grep -q 'dex.local.howso.com' /etc/hosts; then
  echo "127.0.0.1  dex.local.howso.com" | sudo tee -a /etc/hosts
else
  echo "Already present, skipping"
fi

echo "=== Adding Dex Helm repository ==="
helm repo add dex https://charts.dexidp.io
helm repo update

echo "=== Creating dex namespace ==="
kubectl create namespace dex 2>/dev/null || true

echo "=== Installing Dex ==="
helm install dex dex/dex --namespace dex -f oidc/manifests/dex.yaml --wait

echo "=== Verifying Dex is running ==="
for i in $(seq 1 30); do
  if curl -sk https://dex.local.howso.com/.well-known/openid-configuration | grep -q issuer; then
    echo "Dex is responding"
    break
  fi
  echo "Waiting for Dex... ($i/30)"
  sleep 5
done

echo "=== Configuring Howso Platform for OIDC ==="
helm upgrade howso-platform \
  oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --values oidc/manifests/howso-platform.yaml \
  --wait --timeout 20m

echo "=== Installation complete ==="
echo "Access https://local.howso.com/ — you should be redirected to Dex login"
echo "Credentials: admin@example.com / password"
echo "Note: Accept certificate warnings for api.local.howso.com and management.local.howso.com first"
