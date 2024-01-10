<img src="assets/logo-gradient-light.png" alt="Logo" width="200"/>

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


### Helm Overview

**Helm** is an indispensable tool in the Kubernetes ecosystem, often referred to as the Kubernetes package manager. It simplifies the process of managing Kubernetes applications through Helm charts — collections of pre-configured Kubernetes resources. These charts streamline the deployment and management process, making it easier to distribute, version, and manage Kubernetes applications.

Helm charts are highly customizable, allowing users to adjust settings to fit their specific requirements. This flexibility, combined with the ease of updating and rolling back deployments, makes Helm a preferred choice for rapid and efficient Kubernetes application management. Whether deploying simple microservices or complex, multi-tiered applications, Helm's approach to packaging and deployment is invaluable for consistent and reproducible environments.



## Examples

- [Helm](helm-basic/README.md)
- [Helm Advanced](helm-full/README.md)
- [Helm Airgap](argocd-basic/README.md)
- [Helm Openshift](argocd-openshift/README.md)
- [ArgoCD Basic](argocd-basic/README.md)
- [ArgoCD Airgap](argocd-airgap/README.md)
