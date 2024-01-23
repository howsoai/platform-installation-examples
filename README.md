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



## Accessing the Howso Platform Helm Registry
Access to the Helm registry for the Howso Platform requires a Howso Platform license.  You'll log in with your email, registered with the customer portal, and your license ID as the credential.

You can find your license ID in two ways: either from the address bar on the downloads page or within your license file, where it's listed under the `license_id:` field.

The charts are stored in an OCI (Open Container Initiative) type registry, and you'll log in using the email registered with the customer portal and your license ID. Use the following command to log in, replacing `your_email@example.com` with your registered email and `your_license_id` with your actual license ID:

```bash
helm registry login registry.how.so --username your_email@example.com --password your_license_id
```

## Quick Start vs Production Readiness

### Out-of-the-Box Interoperability
The Helm charts for the Howso Platform, including Redis, PostgreSQL, MinIO, and NATS, are designed to work together seamlessly in (an almost) default configurations. With the exception of some small changes (i.e. enabling JetStream in NATS) these charts require minimal setup for a quick start. This interoperability facilitates an easy and efficient initial deployment of the Howso Platform.

In the _basic_ examples, this type of configuration will be demonstrated.  It is recommended to start with this configuration before more complex arrangements.

### Considerations for Production Environments
While the default configurations are suitable for a quick start and testing purposes, they are not intended for hardened, production-level deployments. Key aspects such as air-gapping, securing communication tunnels, appeasing OpenShift policies, and scaling will require additional configuration. 

Though not exhaustive, the included _advanced_, _airgap_ and _openshift_ examples will demonstrate how some of these configurations can be achieved. 

### Secret management
The examples will typically create secrets as a seperate step - creating an _existing secret_ for charts to use.  This is a reasonable approach on its own - as the secrets need only be known between the platform and datastore.  However, including as a seperate step should make it clear where additional secret management tools (external-secrets) could be used instead.


## Resource Management and Node Grouping in Howso Platform

### Understanding Resource Needs
The Howso Platform is a resource-intensive machine learning platform. It dynamically creates new workloads through an operator, which require considerable CPU and memory resources. For optimal performance, the platform should be set up in an environment with a substantial number of available nodes, ideally within an autoscaling infrastructure. This setup ensures that the platform can scale resources efficiently as workloads increase.

### Recommended Node Grouping for Autoscaling
A practical approach to manage resources in an autoscaling cluster (such as EKS or AKS) is to use two distinct node groups:

- **Core Node Group**: This group hosts all non-trainee pods. It's crucial for the stability and running of the platform's core functions.
- **Worker Node Group**: Dedicated to worker pods, this group handles the dynamic, resource-heavy workloads typical in machine learning tasks.

### Applying Taints and Labels for Effective Scaling
To optimize resource allocation and ensure that pods are scheduled on the appropriate nodes, use [taints and labels](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/):

1. Restrict Worker Pods on Core Nodes:
   Label the core node group to prevent worker pods from being scheduled on these nodes:
   ```bash
   kubectl label nodes $NODE howso.com/allowWorkers=False
    ```
2. Dedicate Worker Nodes for Worker Pods
Label and taint the worker node group to allow only worker pods and actively remove other types of pods:
    ```bash
    kubectl taint nodes $NODE howso.com/nodetype=worker:NoExecute
    ```
These practices ensure that the Howso Platform operates within a well-organized, resource-optimized environment. The core node group maintains the essential services, while the worker node group dynamically scales to meet the demands of machine learning workloads, enhancing overall efficiency and performance.


## Example Structure

The examples should work in any kubernetes cluster, but to make them easy to work with locally, examples using [k3d] are provided.  The OpenShift examples should use a [CodeReady Containers](https://developers.redhat.com/products/codeready-containers/overview).  Checkout the [prereqs](prereqs/README.md) for more details. 

