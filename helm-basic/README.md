# Helm Non-Airgap Installation for Howso Platform

## Introduction
This guide details the process of deploying the Howso Platform using Helm in a non-airgapped Kubernetes environment.

## Overview
This documentation focuses on deploying the Howso Platform using Helm, emphasizing a straightforward installation process for environments with direct internet access.

## Limitations
This guide provides a basic walkthrough of Helm usage and does not cover advanced features or complex customization options.

## Licensing Note
> MinIO, under the AGPL license, is included with Howso Inc.'s OEM license for commercial Howso Platform deployments, covering usage up to 1 terabyte. For extensive deployments, ensure compliance with a fully licensed Minio installation or an S3 compatible alternative.

## Tools and Technologies
- Helm
- Kubernetes
- Replicated KOTS application

## Prerequisites
- Access to a Kubernetes cluster with internet connectivity
- Helm installed and configured

## Installation Steps
### Helm Repository Setup
   ```bash
   helm repo add howso-platform https://charts.howso.com
   helm repo update
   ```

### Install Component Charts
   - Install MinIO:
     ```bash
     helm install platform-minio howso-platform/minio --create-namespace --namespace howso --set mode=standalone --wait
     ```
   - Install NATS:
     ```bash
     helm install platform-nats howso-platform/nats --namespace howso --set config.jetstream.enabled=true --wait
     ```
   - Install PostgreSQL:
     ```bash
     helm install platform-postgres howso-platform/postgresql --namespace howso --wait
     ```
   - Install Redis:
     ```bash
     helm install platform-redis howso-platform/redis --namespace howso --wait
     ```
   - Install Howso Platform:
     ```bash
     helm install howso-platform howso-platform/howso-platform --namespace howso --set domain=local.howso.com --wait
     ```

## Finalizing Installation
Check that all components are successfully installed and running by inspecting the pod status in the `howso` namespace.

## Troubleshooting and Support
For assistance, consult the Helm documentation or reach out to Howso Platform support.

---


