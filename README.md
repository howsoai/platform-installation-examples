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
- [Helm](helm-basic/README.md)
- [Helm Air-gap](helm-airgap/README.md)
- [Helm Openshift](helm-openshift/README.md)
- [Argo CD Basic](argocd-basic/README.md)

### Argo Workflows Integration

The Howso Platform can optionally integrate with Argo Workflows to enable certain workflow automation capabilities. Like the core platform components, this is available as a Helm chart and can be added to an existing platform installation.
- [Argo Workflows Integration](./argo-workflows/README.md)

> Note: Workflows integration is available in Howso Platform 2024.12.0 and later as an early access feature.

## Overview

Howso Platform is a Kubernetes-based application that consists of many services, it is available as a Helm chart install, depending on data stores and a message queue that can also be deployed as charts.


### Replicated

The Howso Platform is distributed as a [Replicated](https://www.replicated.com/) application.  Replicated is a Kubernetes application distribution platform that facilitates self-hosted installation of Kubernetes applications.  This documentation will mostly cover accessing the application as Replicated hosted Helm charts.  


### Helm

[Helm](https://helm.sh/) modularizes Kubernetes manifests into charts, which can be installed, upgraded, and uninstalled as a single entity. It includes a straightforward method for templating out certain values, to make it simple to configure the application.

The Howso Platform relies on data stores, such as Postgres, Redis, an S3-compatible object store (Minio), and a message queue (NATS).  These requirements can themselves be deployed as Helm charts.  The documentation will use commonly available charts for these dependencies.  These public charts are configurable and mature enough to provide a range from simple tests to scaled production configurations.


## Quick Start vs Production Readiness

### Out-of-the-Box Interoperability

The Howso Platform chart is designed to work together well with the dependent Helm charts for Redis, PostgreSQL, MinIO, and NATS, in an (almost) default configuration.  Except for some small changes (i.e. enabling JetStream in NATS), these charts require minimal setup for a quick start. This interoperability facilitates an easy and efficient initial deployment of the Howso Platform.

In the _basic_ examples, this type of configuration will be demonstrated.  It is recommended to start with this configuration before more complex arrangements.


### Considerations for Production Environments

While the default configurations are suitable for a quick start and testing purposes, they are not intended for hardened, production-level deployments. Key aspects such as air-gapping (deploying to environments with no internet access), securing communication tunnels, adhering to OpenShift policies, and scaling, all require additional configuration. 

Though not exhaustive, the included [air-gap](./helm-airgap/README.md) and [OpenShift](./helm-openshift/) examples will demonstrate how some more complex configurations can be achieved. 


### Observability

The Howso Platform can publish metrics and traces using the [OpenTelemetry](https://opentelemetry.io) system beginning with release 2024.6.1.  This depends on a collector being installed in the cluster.  There is a [basic OpenTelemetry sample setup](opentelemetry/README.md) that installs the collector and configures the Howso Platform to send it data.  An [extended end-to-end OpenTelemetry sample setup](opentelemetry-e2e/README.md) installs additional open-source observability tools to examine and monitor the system state.


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


## Licensing Note

MinIO is used as the default S3 object store with the Howso Platform.  For production deployments ensure you have a valid license for MinIO.
MinIO, under the AGPL license, is included with Howso Inc.'s OEM license for commercial Howso Platform deployments, covering usage up to 1 terabyte.
