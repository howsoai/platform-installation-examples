#!/usr/bin/env bash
set -euo pipefail

# Argo CD Installation — Option 2: External Charts Mode
# See argocd-basic/README.md for full documentation.
# Run from the repository root directory.
#
# Prerequisites:
#   - argocd CLI installed (https://argo-cd.readthedocs.io/en/stable/cli_installation/)
#   - Helm registry login completed

echo "=== Creating k3d cluster ==="
k3d cluster create --config prereqs/k3d-single-node.yaml

echo "=== Creating howso namespace ==="
kubectl create namespace howso

echo "=== Installing Argo CD ==="
kubectl apply -k argocd-basic/manifests/argocd/

echo "=== Waiting for Argo CD to be ready ==="
kubectl -n argocd wait --for=condition=ready --timeout=180s pod -l app.kubernetes.io/name=argocd-server

echo "=== Logging into Argo CD ==="
initial_argocd_pw=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd --insecure --grpc-web login argocd.local.howso.com --username admin --password "$initial_argocd_pw"
echo "Log into argocd at https://argocd.local.howso.com with username admin and password $initial_argocd_pw"

echo "=== Applying CRDs ==="
helm template oci://registry.how.so/howso-platform/stable/howso-platform \
  --show-only 'templates/crds/*.yaml' | kubectl apply -f -

echo "=== Adding chart registry to Argo CD ==="
echo "Run manually: argocd repo add registry.how.so --type helm --name replicated --username youremail@example.com --password <your-license-id> --enable-oci"

echo "=== Creating datastore secrets ==="
kubectl create secret generic platform-minio \
  --from-literal=rootPassword="$(openssl rand -base64 20)" \
  --from-literal=rootUser="$(openssl rand -base64 20)" \
  --dry-run=client -o yaml | kubectl -n howso apply -f -

kubectl create secret generic platform-postgres-postgresql \
  --from-literal=postgres-password="$(openssl rand -base64 20)" \
  --dry-run=client -o yaml | kubectl -n howso apply -f -

kubectl create secret generic platform-redis \
  --from-literal=redis-password="$(openssl rand -base64 20)" \
  --dry-run=client -o yaml | kubectl -n howso apply -f -

echo "=== Deploying Argo CD applications ==="
kubectl apply -f argocd-basic/manifests/argocd-project.yaml
kubectl apply -f argocd-basic/manifests/argocd-required-apps.yaml
kubectl apply -f argocd-basic/manifests/argocd-howso-platform-app.yaml

echo "=== Installation complete ==="
echo "Check status: argocd app list"
echo "Monitor pods: watch kubectl -n howso get po"
echo "Argo CD UI: https://argocd.local.howso.com"
echo "Next steps: see common/README.md#login-to-the-howso-platform"
