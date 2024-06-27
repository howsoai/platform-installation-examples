# OpenTelemetry

## Prerequisites

- [General prerequisites](../prereqs/README.md)
- [Helm Online Installation for Howso Platform](../helm-basic/README.md)

## Introduction

[OpenTelemetry](https://opentelemetry.io) is a unified open-source observability tool.  It includes common code for collecting metrics, traces, and logs across a distributed system.

To process telemetry data, the Howso Platform requires that the cluster be running an [OpenTelemetry collector](https://opentelemetry.io/docs/collector/).  Individual components of the system forward data to the collector, which in turn forwards it onwards to other observability tools.  An OpenTelemetry collector might forward traces to a [Jaeger](https://www.jaegertracing.io/) instance and metrics to [Prometheus](https://prometheus.io), for example.  So long as the collector is running, the Howso Platform is agnostic to the specific choice of observability backends.

The Howso Platform does not require an OpenTelemetry collector for standard data processing and synthesis tasks.  It is only required to collect more detailed metrics about individual components' operation and to debug performance and scaling problems in the system.

## Installing the Collector

There are several ways to install the collector.  For this example, we will use the [OpenTelemetry Collector Chart](https://opentelemetry.io/docs/kubernetes/helm/collector/):

```sh
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm install platform-opentelemetry-collector \
  open-telemetry/opentelemetry-collector \
  --namespace howso \
  --values opentelemetry/manifests/opentelemetry-collector.yaml
```

This default configuration installs a collector, but does not necessarily send its output anywhere.  The chart can take [extended configuration options](https://opentelemetry.io/docs/kubernetes/helm/collector/#configuration) that tell it where to forward traces and metrics when it receives them.

In the [Helm configuration](manifests/opentelemetry-collector.yaml) we enable the "contrib" version of the collector.  This includes a number of extended destinations and processing options.  We also configure the collector to inject Kubernetes-related metadata into traces and metrics as it receives them.  The collector has a number of other configuration settings, and different configurations may require it to be run as a Deployment (fixed number of cluster-wide collector instances) or as a DaemonSet (one collector on each cluster node).

The Howso Platform also needs to be configured to enable OpenTelemetry data collection, with the URL of the collector.  This is a small [Helm configuration](manifests/howso-platform.yaml) that can be included with the other configuration for the Howso Platform.  Working from the [basic Helm installation](../helm-basic/README.md) this can be added in as additional Helm values

```sh
helm upgrade --install install howso-platform \
  oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --values opentelemetry/manifests/howso-platform.yaml  # <-- add to basic setup
```

These examples install a dedicated OpenTelemetry collector for the Howso Platform, in the same namespace.  So long as the configured collector URL is reachable from the Kubernetes Pods, the collector does not necessarily need to be in the same namespace or even in the cluster.

This setup does not significantly configure the OpenTelemetry collector.  If you look at its output

```sh
kubectl logs --namespace howso deployment/platform-opentelemetry-collector
```

it outputs messages that it is receiving data, but these data are not processed or forwarded anywhere.

## Further Configuration

Your local environment may already contain core observability tools.  For example, the OpenTelemetry collector can forward metrics to a Prometheus push gateway.

The [OpenTelemetry collector configuration](https://opentelemetry.io/docs/collector/configuration/) documentation describes the available configuration options.  All of the options shown in that documentation can be put under a `config:` key in the Helm values; the [end-to-end sample collector configuration](../opentelemetry-e2e/manifests/opentelemetry-collector.yaml) demonstrates this.

The Howso Platform publishes all data to a gRPC endpoint on port 4317 in the collector.  This receiver must be enabled but others can be disabled if needed.

## Extended Example

[OpenTelemetry End-to-End Setup](../opentelemetry-e2e/README.md) contains an extended setup, installing Prometheus, Grafana, Jaeger, and the OpenTelemetry collector in a new cluster.