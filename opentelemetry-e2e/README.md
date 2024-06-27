# OpenTelemetry End-to-End Setup

This example builds on the general [OpenTelemetry setup](../opentelemetry/README.md) with an end-to-end installation.  The previous example installed the OpenTelemetry collector, and configured the Howso Platform to talk to it.  This example additionally installs

- [Prometheus](https://prometheus.io/), to collect metrics;
- [Grafana](https://grafana.com/), to display metrics on dashboards; and
- [Jaeger](https://jaegertracing.io/), to collect and display distributed traces

and then configures the OpenTelemetry collector to publish to these components.

## Kube-Prometheus Stack

The [Kube-Prometheus Stack](https://github.com/prometheus-operator/kube-prometheus) is a prepackaged metric-management system for Kubernetes.  It includes both Prometheus and Grafana, a set of prebuilt Grafana dashboards, and a Kubernetes operator to manage these tools via in-cluster configuration.  The stack can be installed via a [Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) which we will use for consistency with our other tools.

There are two options that need to be configured.  The Helm chart includes Kubernetes Ingress resources that allow external callers to reach Prometheus and Grafana, and we need to configure their host names.  We also need to enable an endpoint in Prometheus to allow the OpenTelemetry collector to push metrics to it.  These settings are included in the [sample Helm values](manifests/kube-prometheus-stack.yaml).

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace howso \
  --values opentelemetry-e2e/manifests/kube-prometheus-stack.yaml
```

## Jaeger

Jaeger can also be installed via a [Helm chart](https://github.com/jaegertracing/helm-charts).

The default Jaeger configuration is a heavy-weight production-oriented installation, including a Cassandra instance as the primary data store.  The [sample Helm values](manifests/jaeger.yaml) here use a much smaller "all-in-one" configuration, with only a single Kubernetes Pod running the entire system.  Note that the configuration here does not persist data outside of the Pod-local filesystem.

```sh
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
helm install jaeger jaegertracing/jaeger \
  --namespace howso \
  --values opentelemetry-e2e/manifests/jaeger.yaml
```

## OpenTelemetry Collector

In the previous example we only minimally configured the OpenTelemetry collector.  We now have destinations for both metrics and traces and we can include those in the collector configuration.  In the [sample extended Helm values](manifests/opentelemetry-collector.yaml) we configure sending metrics to Prometheus's push gateway, and traces to Jaeger using gRPC without TLS.  This configuration also disables the collector endpoints other than the OpenTelemetry OTLP endpoints.

```sh
helm upgrade --install platform-opentelemetry-collector \
  open-telemetry/opentelemetry-collector \
  --namespace howso \
  --values opentelemetry/manifests/opentelemetry-collector.yaml \
  --values opentelemetry-e2e/manifests/opentelemetry-collector.yaml
```

## Accessing the Observability UIs

The configurations here create Kubernetes Ingress resources for the various components.  In the [prerequisites](../prereqs/README.md#setup-hosts), we added entries to the local hosts file to be able to access the Howso Platform.  Additionally include in the hosts file

```none
127.0.0.1 grafana.local.howso.com
127.0.0.1 jaeger.local.howso.com
127.0.0.1 prometheus.local.howso.com
```

[Jaeger](http://jaeger.local.howso.com) shows distributed traces.  As you make requests using the Howso client library, it collects records that show how requests pass through the system and some details of what happens inside each request.  Traces have more detailed information, but are also expensive to collect.  A typical tracing configuration will drop a significant fraction of traces, maybe only keeping error traces plus 1% of non-error traces.

[Prometheus](http://prometheus.local.howso.com) collects metrics.  Metrics are almost always aggregated, so you cannot see individual requests' data, but you can see the overall state of the system over time.  The Howso Platform emits relatively few metrics but you can browse for example `http_server_duration_milliseconds_count` to see the number of HTTP requests that each component of the system receives.

[Grafana](http://grafana.local.howso.com) (`admin`/`prom-operator` default login) displays metrics on dashboards.  The Howso Platform does not include any custom dashboards, but the Kube-Prometheus stack does install some Kubernetes-related dashboards.  You can use the "Explore" tab to construct queries against the Prometheus backend.
