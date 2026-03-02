#!/usr/bin/env bash
set -euo pipefail

# OpenTelemetry Collector — Add-on
# See opentelemetry/README.md for full documentation.
# Run from the repository root directory.
#
# Prerequisites:
#   - Howso Platform running (e.g., via helm-basic/install.sh)

echo "=== Adding OpenTelemetry Helm repository ==="
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

echo "=== Installing OpenTelemetry Collector ==="
helm install platform-opentelemetry-collector \
  open-telemetry/opentelemetry-collector \
  --namespace howso \
  --values opentelemetry/manifests/opentelemetry-collector.yaml \
  --wait

echo "=== Enabling OpenTelemetry in Howso Platform ==="
helm upgrade howso-platform \
  oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --values opentelemetry/manifests/howso-platform.yaml \
  --wait --timeout 20m

echo "=== Installation complete ==="
echo "Check collector logs: kubectl logs --namespace howso deployment/platform-opentelemetry-collector"
echo "Extended setup: see opentelemetry-e2e/README.md"
