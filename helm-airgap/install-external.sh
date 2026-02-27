#!/usr/bin/env bash
set -euo pipefail

# Helm Air-gap Installation — Option 2: External Charts Mode
# See helm-airgap/README.md for full documentation.
# Run from the repository root directory.

AIRGAP_BUNDLE="${AIRGAP_BUNDLE:-}"
if [ -z "$AIRGAP_BUNDLE" ]; then
  echo "AIRGAP_BUNDLE not set. Download from the Howso Customer Portal:"
  echo "  https://portal.howso.com/"
  echo "Then: AIRGAP_BUNDLE=~/2026.2.3.airgap bash $0"
  exit 1
fi

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

echo "=== Downloading Helm charts ==="
tmp_dir=$(mktemp -d)
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo update
helm pull oci://registry-1.docker.io/bitnamicharts/minio --untar --untardir "$tmp_dir"
helm pull nats/nats --untar --untardir "$tmp_dir"
helm pull oci://registry-1.docker.io/bitnamicharts/postgresql --untar --untardir "$tmp_dir"
helm pull oci://registry-1.docker.io/bitnamicharts/redis --untar --untardir "$tmp_dir"
helm pull oci://registry.how.so/howso-platform/stable/howso-platform --untar --untardir "$tmp_dir"

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

echo "=== Installing MinIO ==="
helm install platform-minio "$tmp_dir/minio" \
  --namespace howso \
  --values helm-airgap/manifests/minio.yaml \
  --wait

echo "=== Installing NATS ==="
helm install platform-nats "$tmp_dir/nats" \
  --namespace howso \
  --values helm-airgap/manifests/nats.yaml \
  --wait

echo "=== Installing PostgreSQL ==="
helm install platform-postgres "$tmp_dir/postgresql" \
  --namespace howso \
  --values helm-airgap/manifests/postgres.yaml \
  --wait

echo "=== Installing Redis ==="
helm install platform-redis "$tmp_dir/redis" \
  --namespace howso \
  --values helm-airgap/manifests/redis.yaml \
  --wait

echo "=== Installing Howso Platform ==="
helm install howso-platform "$tmp_dir/howso-platform" \
  --namespace howso \
  --values helm-external-charts/manifests/values-external-all.yaml \
  --values helm-airgap/manifests/howso-platform.yaml

echo "=== Installation complete ==="
echo "Monitor pods: watch kubectl -n howso get po"
echo "Verify images from local registry: kubectl -n howso get po -oyaml | grep 'image:'"
echo "Next steps: see common/README.md#login-to-the-howso-platform"
