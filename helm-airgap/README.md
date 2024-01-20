# Helm Airgap Installation for Howso Platform

## Introduction
This guide outlines the deployment of the Howso Platform using ArgoCD and Helm in an airgapped Kubernetes environment.

## Overview
Deploy the Howso Platform using ArgoCD's Helm chart capabilities, focusing on a minimal configuration that's functional for the Howso Platform and its dependent charts.

## Limitations
This example covers basic ArgoCD usage and is not a comprehensive guide to all features.

## Licensing Note
> MinIO, under AGPL license, is used with Howso Inc.'s OEM license for commercial Howso Platform deployments, covering up to 1 terabyte. Beyond personal testing, ensure a fully licensed Minio installation or an S3 compatible alternative.

## Tools and Technologies
- ArgoCD
- Helm
- Kubernetes
- Replicated KOTS application

## Prerequisites
- Access to a Kubernetes cluster
- Helm installed and configured
- Access to Replicated's Helm repository

## Installation Steps
### Push Images to Local Registry
   ```bash
   kubectl kots admin-console push-images /path/to/airgap/images registry-localhost:5000 --registry-username reguser --registry-password pw --namespace howso --skip-registry-check
   ```

### Helm Registry Authentication

   - Log in:
     ```bash
     helm registry login registry.how.so --username your_email@example.com --password your_password
     ```

### Install Component Charts
   - Install MinIO:
     ```bash
     helm install platform-minio oci://registry.how.so/howso-platform/minio --create-namespace --namespace howso --values /path/to/minio/values.yaml --wait
     ```
   - Install NATS:
     ```bash
     helm install platform-nats oci://registry.how.so/howso-platform/nats --namespace howso --values /path/to/nats/values.yaml --wait
     ```
   - Install PostgreSQL:
     ```bash
     helm install platform-postgres oci://registry.how.so/howso-platform/postgresql --namespace howso --wait
     ```
   - Install Redis:
     ```bash
     helm install platform-redis oci://registry.how.so/howso-platform/redis --namespace howso --wait
     ```
   - Install Howso Platform:
     ```bash
     helm install howso-platform oci://registry.how.so/howso-platform/howso-platform --namespace howso --values /path/to/howso-platform/values.yaml --wait
     ```

## Finalizing Installation
Verify all components are installed and running by checking pod status in the `howso` namespace.

## Troubleshooting and Support
Refer to ArgoCD and Helm documentation or contact Howso Platform support for troubleshooting assistance.

---
