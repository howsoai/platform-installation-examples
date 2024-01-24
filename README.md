<img src="assets/logo-gradient-light-bg.png" alt="Logo" width="200"/>

# Howso Platform Setup Examples

This repository contains examples of how to set up the Howso Platform in various configurations based around Helm charts.

## Examples
- [Pre-requisites](prereqs/README.md)

- [Helm](helm-basic/README.md)
- [Helm Advanced](helm-full/README.md)
- [Helm Airgap](helm-airgap/README.md)
- [Helm Openshift](helm-openshift/README.md)
- [ArgoCD Basic](argocd-basic/README.md)
- [ArgoCD Basic](argocd-helm-template/README.md)
- [ArgoCD Airgap](argocd-airgap/README.md)

## Overview
Howso Platform is a kubernetes application that consists of many services, packaged as a helm chart.  

Helm modularizes kubernetes manifests into charts, which can be installed, upgraded, and uninstalled. It allows a straightforward method for templating out certain values, to make it simple to configure the application.

The Howso Platform relies on datastores, such as postgres, redis, and an s3 compatible object store, and a message queue (NATS).  These requirements can themselves be deployed as helm charts.  The documentation will use common available charts for these dependencies, that are configurable enough to provide a range from simple tests to scaled production configurations.


### Replicated
The Howso Platform is distributed as a [Replicated](https://www.replicated.com/) application.  Replicated is a kubernetes application distribution platform that facilitates self-hosted installation of kubernetes applications.  This documentation will focus on accessing the application as Replicated hosted helm charts - see the [Howso Platform documenation](https://portal.howso.com) for [KOTS](https://kots.io/) installation instructions.  KOTS provides methods for standalone (without an existing kubernetes) installer, and to install into an existing cluster; in both cases wrapping all the components into a single installer.



## Quick Start vs Production Readiness

### Out-of-the-Box Interoperability
The Helm charts for the Howso Platform, including Redis, PostgreSQL, MinIO, and NATS, are designed to work together seamlessly in (an almost) default configurations. With the exception of some small changes (i.e. enabling JetStream in NATS) these charts require minimal setup for a quick start. This interoperability facilitates an easy and efficient initial deployment of the Howso Platform.

In the _basic_ examples, this type of configuration will be demonstrated.  It is recommended to start with this configuration before more complex arrangements.

### Considerations for Production Environments
While the default configurations are suitable for a quick start and testing purposes, they are not intended for hardened, production-level deployments. Key aspects such as air-gapping, securing communication tunnels, appeasing OpenShift policies, and scaling will require additional configuration. 

Though not exhaustive, the included _advanced_, _airgap_ and _openshift_ examples will demonstrate how some of these configurations can be achieved. 

### Secret management
The examples will typically create secrets as a seperate step - creating an _existing secret_ for charts to use.  This is a reasonable approach on its own - as the secrets need only be known between the platform and datastore.  However, including as a seperate step should make it clear where additional secret management tools (external-secrets) could be used instead.

## Example Structure

The examples should work in any kubernetes cluster, but to make them easy to work with locally, examples using [k3d] are provided.  The OpenShift examples should use a [CodeReady Containers](https://developers.redhat.com/products/codeready-containers/overview).  Checkout the [prereqs](prereqs/README.md) for more details. 

All paths are relative to the root of this repository.


## Licensing Note
MinIO is used at the default s3 object store with Howso Platform.  For production deployments ensure you have a valid license for MinIO.
MinIO, under the AGPL license, is included with Howso Inc.'s OEM license for commercial Howso Platform deployments, covering usage up to 1 terabyte.


## Troubleshooting and Support
For assistance, consult the documentation:-

- [Howso Platform](https://portal.howso.com) 
- [Helm](https://helm.sh/docs/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [Bitnami Redis Chart](https://github.com/bitnami/charts/tree/main/bitnami/redis)
- [MinIO Community Chart](https://github.com/minio/minio/tree/master/helm/minio)
- [NATS Chart](https://github.com/nats-io/k8s/tree/main/helm/charts/nats)

Or reach out to Howso Platform support (support@howso.com).

