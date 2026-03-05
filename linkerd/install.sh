#!/usr/bin/env bash
set -euo pipefail

# Linkerd Service Mesh — Add-on
# See linkerd/README.md for full documentation.
# Run from the repository root directory.

if ! command -v step &>/dev/null; then
  echo "Error: 'step' CLI is required but not found."
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
# Alternative: Instead of skipping ports, you can disable builtin TLS entirely
# and let Linkerd handle encryption. Install the chart with:
#   helm install ... -f values-builtin-notls.yaml
# See the chart's values-builtin-notls.yaml and linkerd/README.md for details.
if kubectl -n howso get statefulset platform-nats &>/dev/null; then
  kubectl -n howso patch statefulset platform-nats --type merge \
    -p '{"spec":{"template":{"metadata":{"annotations":{"config.linkerd.io/skip-inbound-ports":"4222"}}}}}'
fi
if kubectl -n howso get statefulset platform-postgres &>/dev/null; then
  kubectl -n howso patch statefulset platform-postgres --type merge \
    -p '{"spec":{"template":{"metadata":{"annotations":{"config.linkerd.io/skip-inbound-ports":"5432"}}}}}'
fi
if kubectl -n howso get statefulset platform-valkey &>/dev/null; then
  kubectl -n howso patch statefulset platform-valkey --type merge \
    -p '{"spec":{"template":{"metadata":{"annotations":{"config.linkerd.io/skip-inbound-ports":"6379"}}}}}'
fi
if kubectl -n howso get statefulset platform-objectstore &>/dev/null; then
  kubectl -n howso patch statefulset platform-objectstore --type merge \
    -p '{"spec":{"template":{"metadata":{"annotations":{"config.linkerd.io/skip-inbound-ports":"9000"}}}}}'
fi

for deploy in $(kubectl -n howso get deployment -o name); do
  kubectl -n howso patch "$deploy" --type merge \
    -p '{"spec":{"template":{"metadata":{"annotations":{"config.linkerd.io/skip-outbound-ports":"4222,5432,6379,9000"}}}}}'
done

if helm status platform-nats -n howso &>/dev/null; then
  helm repo add nats https://nats-io.github.io/k8s/helm/charts/ 2>/dev/null || true
  helm repo update nats
  helm upgrade platform-nats nats/nats --namespace howso --values linkerd/manifests/nats.yaml --wait
fi

echo "=== Restarting Howso Platform pods for sidecar injection ==="
kubectl -n howso delete po --all --wait=false

echo "=== Waiting for pods to come back ==="
sleep 30
kubectl -n howso wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/part-of=howso-platform 2>/dev/null || true

echo "=== Installation complete ==="
echo "Dashboard: linkerd viz dashboard (or kubectl -n linkerd-viz port-forward svc/web 8084:8084)"
echo "Check edges: linkerd viz edges -n howso po"
echo "Next steps: see linkerd/README.md#network-policies"
