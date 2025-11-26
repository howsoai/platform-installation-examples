<img src="assets/logo-gradient-light-bg.png" alt="Logo" width="200"/>

# Howso Platform Setup Examples

This repository contains runnable examples of Howso Platform installations, in various configurations, predominantly based on the use of Helm charts.

## Documentation Approach

The Howso Platform installation and configuration guides focus on setting up fully functional local environments.  

Real production installations often involve multiple teams with split responsibilities and permissions; complex security procedures; delays for provisioning and approval processes.  Navigating these institutional challenges whilst also applying configurations and integrations to Howso Platform is complex.

By providing self-contained local workstation setups the documentation aims to:-
- Avoid delaying seeing a working system until all other things are in place.
- Provide a real environment to gain hands on experience and a place to experiment with configuration options.


## Examples
- [Prerequisites](prereqs/README.md)
---
- [Helm (Built-in Services)](helm-basic/README.md)
- [Helm (External Charts)](helm-external-charts/README.md) - Use external Bitnami/MinIO charts
- [Helm Air-gap](helm-airgap/README.md)
- [Helm Openshift](helm-openshift/README.md)
- [Argo CD Basic](argocd-basic/README.md)

### Argo Workflows Integration

The Howso Platform can optionally integrate with Argo Workflows to enable certain workflow automation capabilities. Like the core platform components, this is available as a Helm chart and can be added to an existing platform installation.
- [Argo Workflows Integration](./argo-workflows/README.md)

> Note: Workflows integration is available in Howso Platform 2024.12.0 and later as an early access feature.

## Overview

Howso Platform is a Kubernetes-based application that consists of many services, available as a single Helm chart. The platform chart includes built-in infrastructure services (Postgres, Valkey, NATS, VersityGW object storage) for simplified deployment, or can be configured to use external charts (Bitnami Postgres/Redis, MinIO, NATS) for other use cases.


### Replicated

The Howso Platform is distributed as a [Replicated](https://www.replicated.com/) application.  Replicated is a Kubernetes application distribution platform that facilitates self-hosted installation of Kubernetes applications.  This documentation will mostly cover accessing the application as Replicated hosted Helm charts.  

> Note: The KOTS installation method uses Valkey (a BSD-licensed Redis alternative) by default. See [Redis licensing update](./redis-license-update.md) for more information.


### Helm

[Helm](https://helm.sh/) modularizes Kubernetes manifests into charts, which can be installed, upgraded, and uninstalled as a single entity. It includes a straightforward method for templating out certain values, to make it simple to configure the application.

The Howso Platform relies on data stores (Postgres, Redis/Valkey), an S3-compatible object store, and a message queue (NATS). By default, these are included as built-in services within the platform chart. Alternatively, they can be deployed as separate Helm charts—see [External Charts](helm-external-charts/README.md) for details.


## Quick Start vs Production Readiness

### Built-in Services (Default)

The Howso Platform chart includes built-in infrastructure services (Postgres, Valkey, NATS, VersityGW) that work together in an almost default configuration. Except for some small changes (i.e. configuring the domain), these services require minimal setup for a quick start. This interoperability facilitates an easy and efficient initial deployment of the Howso Platform.

In the [helm-basic](helm-basic/README.md) examples, this type of configuration will be demonstrated. It is recommended to start with this configuration before more complex arrangements.

### External Charts

Alternatively, the platform can be configured to use external Bitnami/MinIO charts instead of built-in services. This approach is useful for:
- Integration with existing infrastructure
- Gradual migration from previous installations
- Organization-specific chart requirements

The [helm-external-charts](helm-external-charts/README.md) guide demonstrates this configuration.


### Considerations for Production Environments

While the default configurations are suitable for a quick start and testing purposes, they are not intended for hardened, production-level deployments. Key aspects such as air-gapping (deploying to environments with no internet access), securing communication tunnels, adhering to OpenShift policies, and scaling, all require additional configuration. 

Though not exhaustive, the included [air-gap](./helm-airgap/README.md) and [OpenShift](./helm-openshift/) examples will demonstrate how some more complex configurations can be achieved. 


### Observability

The Howso Platform can publish metrics and traces using the [OpenTelemetry](https://opentelemetry.io) system beginning with release 2024.6.1.  This depends on a collector being installed in the cluster.  There is a [basic OpenTelemetry sample setup](opentelemetry/README.md) that installs the collector and configures the Howso Platform to send it data.  An [extended end-to-end OpenTelemetry sample setup](opentelemetry-e2e/README.md) installs additional open-source observability tools to examine and monitor the system state.  Observability data can also be [published to Azure Monitoring](opentelemetry-aks/README.md) if you are running Howso Platform on Microsoft's Azure Kubernetes Service.


### Securing Howso Platform

Securing the Howso Platform is discussed in the [security](security/README.md) section.  This includes the use of Service Mesh, Network Policies, and other security topics. 


## Example Structure

The examples should work in any Kubernetes cluster, but for simple local installation demonstrations, [k3d](https://k3d.io/) has been used.  Check out the [prereqs](prereqs/README.md) for more details. 

When running commands, all paths are relative to the root of this repository.

> Note: Following the examples directly, you will end up with files (such as `howso.yml` or local platform certs) under the repo root, those have been added to the `.gitignore` file, so you won't see those files in your git status.


## Configuration

The Howso Platform supports configuration options to tailor your installation. These include ingress setup, authentication methods, domain customization, etc.

For details on configuring your Howso Platform deployment, refer to the [Configuration Guide](configuration/README.md).


## Trainee Scaling

The Howso Platform can automatically set the resource requirements for a trainee, increasing them as the trainee's memory utilization increases.  This setup is discussed in the [trainee scaling](trainee-scaling/README.md) section.
