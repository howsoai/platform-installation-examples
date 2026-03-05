#!/usr/bin/env bash
set -euo pipefail

# MINC (MicroShift in Container) Setup
#
# Creates a local OpenShift-compatible cluster using MINC with:
# - Local container registry at registry-localhost:5000
# - Local-path storage provisioner (default StorageClass)
# - OpenShift Security Context Constraints (SCCs)
#
# Prerequisites:
#   - minc:   https://github.com/minc-org/minc
#   - podman: https://podman.io/
#
# Usage:
#   sudo bash prereqs/minc-setup.sh          # Create cluster
#   sudo bash prereqs/minc-setup.sh teardown  # Delete cluster
#
# After setup, use kubectl with context 'microshift':
#   kubectl config use-context microshift
#   kubectl get scc   # Verify OpenShift SCCs are available

ACTION="${1:-create}"

# Resolve the real user's home directory (when run with sudo)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

# Helper: Run podman with appropriate privileges
_podman_cmd() {
    if [ "$(uname -s)" = "Darwin" ]; then
        podman "$@"
    else
        # Already running as root (sudo), call podman directly
        podman "$@"
    fi
}

# Helper: Stop anything already listening on port 5000
_free_port_5000() {
    local pid
    pid=$(lsof -ti :5000 2>/dev/null || true)
    if [ -n "$pid" ]; then
        echo "  Stopping process on port 5000 (pid $pid)"
        kill "$pid" 2>/dev/null || true
        sleep 2
    fi
    # Also stop any Docker container using port 5000
    if command -v docker &>/dev/null; then
        local cid
        cid=$(docker ps -q --filter "publish=5000" 2>/dev/null || true)
        if [ -n "$cid" ]; then
            echo "  Stopping Docker container on port 5000"
            docker stop "$cid" 2>/dev/null || true
            docker rm "$cid" 2>/dev/null || true
        fi
    fi
}

_teardown() {
    echo "=== Tearing down MINC cluster ==="
    minc delete || true

    if _podman_cmd ps -a --format '{{.Names}}' | grep -q '^registry$'; then
        echo "Removing local registry"
        _podman_cmd stop registry || true
        _podman_cmd rm registry || true
    fi

    if grep -q "registry-localhost" /etc/hosts; then
        echo "Removing registry-localhost from /etc/hosts"
        if [ "$(uname -s)" = "Darwin" ]; then
            sed -i '' '/registry-localhost/d' /etc/hosts
        else
            sed -i '/registry-localhost/d' /etc/hosts
        fi
    fi

    echo "=== MINC cluster removed ==="
}

if [ "$ACTION" = "teardown" ]; then
    _teardown
    exit 0
fi

# --- Create ---

echo "=== Creating MINC cluster ==="
minc create --http-port 80 --https-port 443 --log-level info

echo "=== Waiting for cluster to be ready ==="
for (( i=1; i<=60; i++ )); do
    if minc status 2>/dev/null | grep -q '"apiserver": "running"'; then
        echo "MINC cluster is running"
        break
    fi
    echo "  Waiting... ($i/60)"
    sleep 10
done

# Copy kubeconfig to the real user (minc writes to root's ~/.kube when run with sudo)
minc generate-kubeconfig 2>/dev/null || true
if [ -f /root/.kube/config ] && [ "$REAL_HOME" != "/root" ]; then
    mkdir -p "$REAL_HOME/.kube"
    # Merge microshift context into user's kubeconfig
    KUBECONFIG="/root/.kube/config:$REAL_HOME/.kube/config" \
      kubectl config view --flatten > "$REAL_HOME/.kube/config.merged"
    mv "$REAL_HOME/.kube/config.merged" "$REAL_HOME/.kube/config"
    chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.kube/config"
    chmod 600 "$REAL_HOME/.kube/config"
fi
export KUBECONFIG="$REAL_HOME/.kube/config"
kubectl config use-context microshift
kubectl get nodes

echo "=== Setting up local registry ==="
_free_port_5000
if _podman_cmd ps -a --format '{{.Names}}' | grep -q '^registry$'; then
    echo "Registry container already exists"
    if ! _podman_cmd ps --format '{{.Names}}' | grep -q '^registry$'; then
        _podman_cmd start registry
    fi
else
    _podman_cmd run -d \
        --name registry \
        -p 5000:5000 \
        --restart=always \
        registry:2
fi

echo "=== Configuring registry-localhost hostname ==="
gateway_ip=$(_podman_cmd inspect microshift --format '{{.NetworkSettings.Gateway}}')
echo "MINC gateway IP: $gateway_ip"

if ! grep -q "registry-localhost" /etc/hosts; then
    echo "127.0.0.1 registry-localhost" >> /etc/hosts
    echo "  Added registry-localhost -> 127.0.0.1 to host /etc/hosts"
fi

_podman_cmd exec microshift bash -c "
    if ! grep -q 'registry-localhost' /etc/hosts; then
        echo '$gateway_ip registry-localhost' >> /etc/hosts
        echo '  Added registry-localhost -> $gateway_ip to MINC /etc/hosts'
    fi
"

echo "=== Configuring insecure registry ==="

# Host user Podman config (write to real user's home, not root's)
mkdir -p "$REAL_HOME/.config/containers/registries.conf.d"
cat > "$REAL_HOME/.config/containers/registries.conf.d/registry-localhost.conf" <<'REGEOF'
unqualified-search-registries = ["docker.io", "quay.io", "registry-localhost:5000"]

[[registry]]
location = "registry-localhost:5000"
insecure = true
REGEOF

# System-level config (Linux)
if [ "$(uname -s)" != "Darwin" ]; then
    mkdir -p /etc/containers/registries.conf.d
    cp "$REAL_HOME/.config/containers/registries.conf.d/registry-localhost.conf" \
       /etc/containers/registries.conf.d/registry-localhost.conf
fi

# Inside MINC container (CRI-O config — CRITICAL)
_podman_cmd exec microshift bash -c 'cat > /etc/containers/registries.conf.d/registry-localhost.conf <<EOF
unqualified-search-registries = ["docker.io", "quay.io", "registry-localhost:5000"]

[[registry]]
location = "registry-localhost:5000"
insecure = true
EOF
'

echo "Restarting MicroShift to apply registry configuration..."
_podman_cmd exec microshift systemctl restart microshift
echo "  Waiting 30s for MicroShift restart..."
sleep 30

echo "Restarting CRI-O to load registry config..."
_podman_cmd exec microshift systemctl restart crio
sleep 5

echo "=== Installing storage provisioner ==="
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
sleep 5

kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl patch scc hostmount-anyuid --type=json \
  -p='[{"op": "add", "path": "/users/-", "value": "system:serviceaccount:local-path-storage:local-path-provisioner-service-account"}]'

kubectl label namespace local-path-storage pod-security.kubernetes.io/enforce=privileged --overwrite
kubectl label namespace local-path-storage pod-security.kubernetes.io/audit=privileged --overwrite

kubectl wait --for=condition=available --timeout=60s \
  deployment/local-path-provisioner -n local-path-storage || true

echo "=== Verifying setup ==="
echo "  Cluster:"
kubectl get nodes
echo "  SCCs:"
kubectl get scc --no-headers | awk '{print "    " $1}'
echo "  Storage:"
kubectl get sc
echo "  Registry:"
curl -s http://registry-localhost:5000/v2/_catalog | head -1

echo ""
echo "=== MINC setup complete ==="
echo "  Context:  kubectl config use-context microshift"
echo "  Registry: registry-localhost:5000"
echo "  Teardown: sudo bash prereqs/minc-setup.sh teardown"
