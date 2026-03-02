#!/usr/bin/env bash
set -euo pipefail

# Linkerd Service Mesh — Add-on
# See linkerd/README.md for full documentation.
# Run from the repository root directory.
#
# Prerequisites:
#   - Howso Platform running with external charts (helm-external-charts/install.sh)
#   - step CLI installed (https://smallstep.com/docs/step-cli/)
#
# Note: Built-in services mode uses internal TLS which conflicts with
# Linkerd's mTLS proxy. Use external charts mode for Linkerd integration.

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

echo "=== Annotating NATS for opaque port handling ==="
# NATS uses a server-speaks-first protocol; Linkerd needs opaque port annotation
if helm status platform-nats -n howso &>/dev/null; then
  # External charts mode: upgrade the NATS helm release with annotations
  helm repo add nats https://nats-io.github.io/k8s/helm/charts/ 2>/dev/null || true
  helm repo update nats
  helm upgrade platform-nats nats/nats --namespace howso --values linkerd/manifests/nats.yaml --wait
else
  # Built-in mode: annotate existing NATS resources directly
  kubectl -n howso annotate svc platform-nats config.linkerd.io/opaque-ports="4222" --overwrite
  kubectl -n howso annotate statefulset platform-nats config.linkerd.io/opaque-ports="4222" --overwrite
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
