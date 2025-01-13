# OpenTelemetry on Azure Kubernetes Service

## Prerequisites

* [OpenTelemetry](../opentelemetry/README.md)

## Introduction

Microsoft's Azure environment includes several standard observability tools, bundled as Azure Monitoring.  The Howso Platform can use the OpenTelemetry stack to publish metrics and traces into Azure Monitoring.

Internally the Howso Platform uses the OpenTelemetry gRPC over-the-wire interface to send observability data to a central collector.  We do not embed the Azure-specific OpenTelemetry distribution libraries.  Instead, the OpenTelemetry collector needs to be configured with the [Azure Monitor Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/azuremonitorexporter) to send data out to Azure.

The setup here builds on top of the general [Howso Platform OpenTelemetry installation instructions](../opentelemetry/README.md).  Also see Microsoft's documentation on [Application Insights](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview) as well as [OpenTelemetry on Azure](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry).

This documentation includes an [extended OpenTelemetry setup](../opentelemetry-e2e/README.md) with several additional open-source tools.  The Azure Monitoring setup includes equivalents of these tools, and you do not need this extended setup if you prefer to use Azure Monitoring for general application observability.

## Configuring OpenTelemetry for Azure

In the Azure portal, select "Monitor" in the row of services at the top of that screen.  Choose "Application insights" on the next screen, or navigate to "Insights" > "Applications" in the left-hand menu.

If you do not already have an Application Insights resource, [create one](https://learn.microsoft.com/en-us/azure/azure-monitor/app/create-workspace-resource?tabs=bicep#create-a-workspace-based-resource).  It should be attached to the same Azure resource group as your main Kubernetes cluster.  Actually creating the setup will take several minutes.

Select the Application Insights resource you wish to use in the Azure portal listing.  A block at the top of the screen is labeled "Essentials", and on the right-hand side is a "Connection String".  Click the "copy" button that appears when you mouse over this string.

You will need a supplemental Helm configuration file to enable the Azure publisher.  This file embeds the Azure Insights connection string, which includes the instrumentation key and other details needed to publish data.  Edit the [`opentelemetry-aks.yaml` manifest file](manifests/opentelemetry-aks.yaml) and replace the `connection_string:` setting with the copied value.

Deploy this configuration along with the [base Howso Platform OpenTelemetry configuration](../opentelemetry/manifests/opentelemetry-collector.yaml):

```sh
helm upgrade --install platform-opentelemetry-collector \
  open-telemetry/opentelemetry-collector \
  --namespace howso \
  --values opentelemetry/manifests/opentelemetry-collector.yaml \
  --values opentelemetry-aks/manifests/opentelemetry-aks.yaml \
  --wait
```

OpenTelemetry support also needs to be enabled in the Howso Platform, as in the [Installing the Collector section of the base OpenTelemetry configuration](../opentelemetry/README.md#installing-the-collector).

## Reviewing Observability Data

Run some workload targeting the installed Howso Platform.  Open the Application Insights resource that was configured above.

Some pages to look at include:

* "Investigate" > "Application map" shows the internal connectivity between the various Howso Platform services
* "Investigate" > "Performance" shows the total time spent in various top-level activities, generally grouped by HTTP URL path
* "Investigate" > "Transaction search" can help you find a specific trace; try entering a Howso API verb such as `react` in the search box
* "Monitoring" > "Metrics" lets you see aggregate operational metrics over time; see Howso-specific metrics under the "CUSTOM" heading in the "Metric" drop-down
