#!/usr/bin/env bash
set -euo pipefail

# Linkerd Service Mesh — Add-on
# See linkerd/README.md for full documentation.
# Run from the repository root directory.
#
# Prerequisites:
#   - Howso Platform running (via helm-basic or helm-external-charts)
#   - step CLI installed (https://smallstep.com/docs/step-cli/)

if ! command -v step &>/dev/null; then
  echo "Error: 'step' CLI is required but not found."
  echo "Install from: https://smallstep.com/docs/step-cli/"
  exit 1
fi

echo "=== Adding Linkerd Helm repository ==="
helm repo add linkerd https://helm.linkerd.io/stable
helm repo update

echo "=== Installing Linkerd CRDs ==="
helm upgrade --install --namespace linkerd --create-namespace linkerd-crds linkerd/linkerd-crds --wait

echo "=== Generating Linkerd certificates ==="
step certificate create root.linkerd.cluster.local linkerd-ca.crt linkerd-ca.key \
  --profile root-ca --no-password --insecure --force
step certificate create identity.linkerd.cluster.local linkerd-issuer.crt linkerd-issuer.key \
  --profile intermediate-ca --not-after 8760h --no-password --insecure \
  --ca linkerd-ca.crt --ca-key linkerd-ca.key --force

echo "=== Installing Linkerd control plane ==="
helm upgrade --install --namespace linkerd \
  --set-file identityTrustAnchorsPEM=linkerd-ca.crt \
  --set-file identity.issuer.tls.crtPEM=linkerd-issuer.crt \
  --set-file identity.issuer.tls.keyPEM=linkerd-issuer.key \
  linkerd-control-plane linkerd/linkerd-control-plane --wait

echo "=== Installing Linkerd Viz (dashboard) ==="
helm upgrade --install --namespace linkerd-viz --create-namespace linkerd-viz linkerd/linkerd-viz --wait

echo "=== Annotating howso namespace for sidecar injection ==="
kubectl annotate namespaces howso linkerd.io/inject=enabled --overwrite

echo "=== Excluding infrastructure service ports from Linkerd proxy ==="
# Built-in infrastructure services (NATS, Postgres, Valkey, ObjectStore) use
# application-level TLS managed by cert-manager. Linkerd's proxy cannot layer
# its mTLS on top of these already-encrypted connections. We use skip-inbound
# on the server side and skip-outbound on the client side so these connections
# bypass the proxy entirely while all other traffic remains in the mesh.
#
# NATS also uses a server-speaks-first protocol that Linkerd cannot detect.
#
# In external-charts mode (plain connections), this is still safe — the
# application TLS handles encryption directly.

INFRA_PORTS="4222,5432,6379,9000"

# Server side: skip inbound proxy for infrastructure service ports
patch_skip_inbound() {
  local name=$1 port=$2
  if kubectl -n howso get statefulset "$name" &>/dev/null; then
    kubectl -n howso patch statefulset "$name" --type merge \
      -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"config.linkerd.io/skip-inbound-ports\":\"$port\"}}}}}"
    echo "  $name: skip-inbound-ports=$port"
  fi
}

patch_skip_inbound platform-nats 4222
patch_skip_inbound platform-postgres 5432
patch_skip_inbound platform-valkey 6379
patch_skip_inbound platform-objectstore 9000

# Client side: skip outbound proxy for all infrastructure ports
echo "  Patching deployments with skip-outbound-ports..."
for deploy in $(kubectl -n howso get deployment -o name); do
  kubectl -n howso patch "$deploy" --type merge \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"config.linkerd.io/skip-outbound-ports\":\"$INFRA_PORTS\"}}}}}"
done

# For external NATS installed via Helm, upgrade the release to include annotations
if helm status platform-nats -n howso &>/dev/null; then
  helm repo add nats https://nats-io.github.io/k8s/helm/charts/ 2>/dev/null || true
  helm repo update nats
  helm upgrade platform-nats nats/nats --namespace howso --values linkerd/manifests/nats.yaml --wait
  echo "  platform-nats: helm release upgraded with opaque port annotations"
fi

echo "=== Restarting Howso Platform pods for sidecar injection ==="
# All pods must restart together so the mesh forms cleanly
kubectl -n howso delete po --all --wait=false

echo "=== Waiting for pods to come back ==="
echo "This may take several minutes as pods restart with Linkerd sidecars"
sleep 30
kubectl -n howso wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/part-of=howso-platform 2>/dev/null || true

echo "=== Installation complete ==="
echo "Dashboard: linkerd viz dashboard (or kubectl -n linkerd-viz port-forward svc/web 8084:8084)"
echo "Check edges: linkerd viz edges -n howso po"
echo "Next steps: see linkerd/README.md#network-policies"
