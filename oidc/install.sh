#!/usr/bin/env bash
set -euo pipefail

# OIDC (Dex) — Add-on
# See oidc/README.md for full documentation.
# Run from the repository root directory.

echo "=== Adding dex.local.howso.com to /etc/hosts ==="
if ! grep -q 'dex.local.howso.com' /etc/hosts; then
  echo "127.0.0.1  dex.local.howso.com" | sudo tee -a /etc/hosts
fi

echo "=== Adding Dex Helm repository ==="
helm repo add dex https://charts.dexidp.io
helm repo update

echo "=== Creating dex namespace ==="
kubectl create namespace dex 2>/dev/null || true

echo "=== Installing Dex ==="
helm install dex dex/dex --namespace dex -f oidc/manifests/dex.yaml --wait

echo "=== Verifying Dex is running ==="
for _ in $(seq 1 30); do
  if curl -sk https://dex.local.howso.com/.well-known/openid-configuration | grep -q issuer; then
    break
  fi
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
