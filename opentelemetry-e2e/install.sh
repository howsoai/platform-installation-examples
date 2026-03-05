#!/usr/bin/env bash
set -euo pipefail

# OpenTelemetry End-to-End — Add-on (Prometheus, Grafana, Jaeger)
# See opentelemetry-e2e/README.md for full documentation.
# Run from the repository root directory.

echo "=== Adding Helm repositories ==="
# may already exist from opentelemetry/install.sh
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

echo "=== Installing Kube-Prometheus Stack ==="
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace howso \
  --values opentelemetry-e2e/manifests/kube-prometheus-stack.yaml \
  --wait

echo "=== Installing Jaeger ==="
helm install jaeger jaegertracing/jaeger \
  --namespace howso \
  --values opentelemetry-e2e/manifests/jaeger.yaml \
  --wait

echo "=== Installing OpenTelemetry Collector (extended config) ==="
helm upgrade --install platform-opentelemetry-collector \
  open-telemetry/opentelemetry-collector \
  --namespace howso \
  --values opentelemetry/manifests/opentelemetry-collector.yaml \
  --values opentelemetry-e2e/manifests/opentelemetry-collector.yaml \
  --wait

echo "=== Enabling OpenTelemetry in Howso Platform ==="
helm upgrade howso-platform \
  oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --values opentelemetry/manifests/howso-platform.yaml \
  --wait --timeout 20m

echo "=== Installation complete ==="
echo "Add these to /etc/hosts if not already present:"
echo "  127.0.0.1 grafana.local.howso.com"
echo "  127.0.0.1 jaeger.local.howso.com"
echo "  127.0.0.1 prometheus.local.howso.com"
echo ""
echo "Grafana:    http://grafana.local.howso.com (admin/prom-operator)"
echo "Jaeger:     http://jaeger.local.howso.com"
echo "Prometheus: http://prometheus.local.howso.com"
