# Installation Example: ArgoCD Installation for Howso Platform

## Overview
This guide demonstrates deploying the Howso Platform using ArgoCD, a GitOps tool for Kubernetes. It emphasizes the use of ArgoCD's Helm chart capabilities to deploy the Howso Platform along with its dependent charts.

## Limitations
This documentation covers basic ArgoCD usage for deploying the Howso Platform. It is not a comprehensive guide to all ArgoCD features.

> **Licensing Note**: MinIO, under the AGPL license, is included in the Howso Platform. Howso Inc. holds an OEM license for Minio, covering Minio storage up to 1 terabyte in commercial deployments. Beyond personal testing, ensure compliance with a fully licensed Minio installation or an S3 compatible alternative.

## Tools and Technologies
- ArgoCD
- Helm
- Kubernetes
- Replicated KOTS application

## Prerequisites
- Access to a Kubernetes cluster.
- Helm installed and configured.
- Access to Replicated's Helm repository.

## Installation Steps
1. **Set Up ArgoCD**
   Ensure ArgoCD is installed and configured on your Kubernetes cluster. 

2. **Create a Project in ArgoCD**
   Apply the `project.yaml` to create a dedicated project for the Howso Platform:
   ```bash
   kubectl apply -f manifests/project.yaml

### Deploy Component Applications
   Apply each application manifest to deploy the respective components:
   - MinIO:
     ```bash
     kubectl apply -f manifests/minio-app.yaml
     ```
   - NATS:
     ```bash
     kubectl apply -f manifests/nats-app.yaml
     ```
   - PostgreSQL:
     ```bash
     kubectl apply -f manifests/postgres-app.yaml
     ```
   - Redis:
     ```bash
     kubectl apply -f manifests/redis-app.yaml
     ```
   - Howso Platform:
     ```bash
     kubectl apply -f manifests/platform-app.yaml
     ```

### Finalizing Installation
Verify the successful deployment of each component in the ArgoCD dashboard. Check the application status and ensure all applications are synchronized and healthy.

### Troubleshooting and Support
For troubleshooting, refer to the ArgoCD documentation or contact Howso Platform support for specific issues related to the platform deployment.

---

