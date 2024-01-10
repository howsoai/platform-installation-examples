<img src="assets/logo-gradient-light-bg.png" alt="Logo" width="200"/>

# Howso Platform Setup Examples

This repository contains examples of how to set up the Howso Platform in various infrastructure formulations.

## Overview
Howso Platform is a kubernetes application that consists of many services, packaged as a helm chart.  It relies on datastores, such as postgresql, redis, and an object store.  These datastores can be deployed as helm charts, or as managed services in a cloud provider, etc.  The documentation will use common available charts, but you can substitute your own charts or managed services. 

### Replicated
The Howso Platform is distributed as a [Replicated](https://www.replicated.com/) application.  Replicated is a kubernetes application distribution platform that facilitates self-hosted installation of kubernetes applications.  This documentation will focus on accessing the application as helm charts - see the Howso Platform documenation for [KOTS](https://kots.io/) installation instructions - both as a standalone installer, and to install into an existing cluster.

### KOTS vs HELM

**KOTS (Kubernetes Off-The-Shelf Software)** is tailored for managing and distributing complex Kubernetes applications. It shines in scenarios requiring detailed configuration, ongoing maintenance, and support, making it a go-to for enterprise-grade deployments. KOTS focuses on application lifecycle management, offering robust tools for versioning, backup, and restore.

Contrastingly, **Helm** is the Kubernetes package manager, akin to apt/yum/homebrew for Linux. It's designed for simplifying the deployment and management of Kubernetes applications. Helm excels in its simplicity and flexibility, making it ideal for rapid deployment and iteration of applications. It's particularly effective for defining, installing, and upgrading even complex Kubernetes apps.

While KOTS offers more extensive management features, Helm provides a more straightforward, agile deployment method. The choice between them depends on the specific needs of your application's lifecycle and operational requirements.

[Replicated Helm Docs](https://docs.replicated.com/vendor/distributing-overview#helm)


### Helm Overview

**Helm** is an indispensable tool in the Kubernetes ecosystem, often referred to as the Kubernetes package manager. It simplifies the process of managing Kubernetes applications through Helm charts — collections of pre-configured Kubernetes resources. These charts streamline the deployment and management process, making it easier to distribute, version, and manage Kubernetes applications.

Helm charts are highly customizable, allowing users to adjust settings to fit their specific requirements. This flexibility, combined with the ease of updating and rolling back deployments, makes Helm a preferred choice for rapid and efficient Kubernetes application management. Whether deploying simple microservices or complex, multi-tiered applications, Helm's approach to packaging and deployment is invaluable for consistent and reproducible environments.


## Accessing the Howso Platform Helm Registry
To access the Helm registry for the Howso Platform, you need to use your license ID as the password. You can find your license ID in two ways: either from the address bar on the downloads page or within your license file, where it's listed under the `license_id:` field. The registry is an OCI (Open Container Initiative) type, and you'll log in using the email registered with the customer portal and your license ID. Use the following command to log in, replacing `your_email@example.com` with your registered email and `your_license_id` with your actual license ID:

```bash
helm registry login registry.replicated.com --username your_email@example.com --password your_license_id
```

## Quick Start vs Production Readiness

### Out-of-the-Box Interoperability
The Helm charts for the Howso Platform, including Redis, PostgreSQL, MinIO, and NATS, are designed to work together seamlessly in their default configurations. With the exception of enabling JetStream in NATS, these charts require minimal setup for a quick start. This interoperability facilitates an easy and efficient initial deployment of the Howso Platform.

### Considerations for Production Environments
While the default configurations are suitable for a quick start and testing purposes, they are not intended for hardened, production-level deployments. Key aspects such as securing communication tunnels to the datastores and managing datastore passwords require additional configurations:

- **Securing Datastore Tunnels**: Setting up mTLS (Mutual TLS) is recommended for securing communication channels. This involves configuring certificates and keys to ensure both client and server authenticate each other’s identities.

- **Managing Datastore Passwords**: Utilizing a secret store for managing datastore passwords enhances security. This involves additional configuration to integrate the secret store with each component of the Howso Platform.

These security enhancements, while vital for a production environment, require a more involved setup and may need to be tailored to your specific infrastructure and security requirements. Some configurations will be demonstrated as examples in our documentation, but the final implementation should be customer-driven, taking into account the specific security policies and infrastructure needs of your organization.


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




## Examples

- [Helm](helm-basic/README.md)
- [Helm Advanced](helm-full/README.md)
- [Helm Airgap](argocd-basic/README.md)
- [Helm Openshift](argocd-openshift/README.md)
- [ArgoCD Basic](argocd-basic/README.md)
- [ArgoCD Airgap](argocd-airgap/README.md)
