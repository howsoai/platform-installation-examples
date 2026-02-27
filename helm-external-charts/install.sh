#!/usr/bin/env bash
set -euo pipefail

# Helm Online Installation — External Charts
# See helm-external-charts/README.md for full documentation.
# Run from the repository root directory.

echo "=== Creating k3d cluster ==="
k3d cluster create --config prereqs/k3d-single-node.yaml

echo "=== Creating howso namespace ==="
kubectl create namespace howso

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

echo "=== Adding Helm repositories ==="
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo update

echo "=== Installing MinIO ==="
helm install platform-minio oci://registry-1.docker.io/bitnamicharts/minio \
  --namespace howso \
  --values helm-external-charts/manifests/minio.yaml \
  --wait

echo "=== Installing NATS ==="
helm install platform-nats nats/nats \
  --namespace howso \
  --values helm-external-charts/manifests/nats.yaml \
  --wait

echo "=== Installing PostgreSQL ==="
helm install platform-postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
  --namespace howso \
  --values helm-external-charts/manifests/postgres.yaml \
  --wait

echo "=== Installing Redis ==="
helm install platform-redis oci://registry-1.docker.io/bitnamicharts/redis \
  --namespace howso \
  --values helm-external-charts/manifests/redis.yaml \
  --wait

echo "=== Installing Howso Platform ==="
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-external-charts/manifests/values-external-all.yaml \
  --values helm-external-charts/manifests/howso-platform.yaml

echo "=== Installation complete ==="
echo "Monitor pods: watch kubectl -n howso get po"
echo "Next steps: see common/README.md#login-to-the-howso-platform"
