<img src="assets/logo-gradient-light-bg.png" alt="Logo" width="200"/>

# Howso Platform Setup Examples

This repository contains examples of how to set up the Howso Platform in various configurations based around Helm charts.

## Examples
- [Pre-requisites](prereqs/README.md)
---
- [Helm](helm-basic/README.md)
- [Helm Air-gap](helm-air-gap/README.md)
- [Helm Openshift](helm-openshift/README.md)
- [ArgoCD Basic](argocd-basic/README.md)

## Overview
Howso Platform is a Kubernetes application that consists of many services, packaged as a helm chart. 


### Replicated
The Howso Platform is distributed as a [Replicated](https://www.replicated.com/) application.  Replicated is a Kubernetes application distribution platform that facilitates self-hosted installation of Kubernetes applications.  This documentation will cover accessing the application as Replicated hosted helm charts.  

### Helm
Helm modularizes Kubernetes manifests into charts, which can be installed, upgraded, and uninstalled. It allows a straightforward method for templating out certain values, to make it simple to configure the application.

The Howso Platform relies on datastores, such as postgres, redis, and an s3 compatible object store, and a message queue (NATS).  These requirements can themselves be deployed as helm charts.  The documentation will use common available charts for these dependencies, that are configurable enough to provide a range from simple tests to scaled production configurations.


## Quick Start vs Production Readiness

### Out-of-the-Box Interoperability
The Helm charts for the Howso Platform, including Redis, PostgreSQL, MinIO, and NATS, are designed to work together seamlessly in (an almost) default configurations. With the exception of some small changes (i.e. enabling JetStream in NATS) these charts require minimal setup for a quick start. This interoperability facilitates an easy and efficient initial deployment of the Howso Platform.

In the _basic_ examples, this type of configuration will be demonstrated.  It is recommended to start with this configuration before more complex arrangements.

### Considerations for Production Environments
While the default configurations are suitable for a quick start and testing purposes, they are not intended for hardened, production-level deployments. Key aspects such as air-gapping (deploying to environments with no internet access), securing communication tunnels, adhering to OpenShift policies, and scaling will require additional configuration. 

Though not exhaustive, the included, _air-gap_ and _openshift_ examples will demonstrate how some of these configurations can be achieved. 

### Secret management
Creating secrets as a seperate step is a good Kubernetes practice.  In the case of Helm installs, it takes the management of the secrets out of the Helm toolchain.  This helps avoid problems where, for instance, argocd, using Helm template behind-the-scenes, both logs secrets, and makes often unintended changes to them.

Including secret creation as a discreet step should also make it clear where additional secret management tools (such as external-secrets) could be used, without complicating the examples.

### Securing Howso Platform
Securing the Howso Platform is discussed in the [security](security/README.md) section.  This includes the use of Service Mesh, Network Policies, and other security topics. 

## Example Structure

The examples should work in any Kubernetes cluster, but to make them easy to work locally, examples using [k3d](https://k3d.io/) are provided.  The OpenShift examples should use [CodeReady Containers](https://developers.redhat.com/products/codeready-containers/overview).  Checkout the [prereqs](prereqs/README.md) for more details. 


All paths are relative to the root of this repository.


## Licensing Note
MinIO is used as the default s3 object store with Howso Platform.  For production deployments ensure you have a valid license for MinIO.
MinIO, under the AGPL license, is included with Howso Inc.'s OEM license for commercial Howso Platform deployments, covering usage up to 1 terabyte.
