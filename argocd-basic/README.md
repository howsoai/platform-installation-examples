# Installation Example: ArgoCD Installation

## Overview
This example demonstrates deploying howso-platform using using ArgoCD, a GitOps tool for managing Kubernetes applications. It focuses on deploying the howso-platform using ArgoCD's Helm chart capabilities.

## Limitations
The example covers basic use of ArgoCD, and is not intended to be a comprehensive guide to ArgoCD's features.  

The focus is on a working minimal configuration for the howso-platform chart and dependent charts.

>  Without a seperate commercial agreement, MinIO, is under the AGPL license.  When deployed as part of a Howso Inc. has an OEM license with Minio - when deployed as part of a commercial howso-platform installation, usage of Minio storage up to 1 terabyte is covered under our OEM license.  Howso Platform should not be deployed beyond personal test use without a fully licensed Minio installation or s3 compatible alternative. 

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
1. **Initial Setup**: Set up ArgoCD in the Kubernetes cluster and ensure it's operational.
2. **Configuration**: Configure ArgoCD to connect to Replicated's Helm repository and set up necessary credentials.
3. **Finalization**: Deploy the howso-platform chart using ArgoCD. Install additional charts for the database, Redis, NATS message queue, and MinIO.

## Troubleshooting
- Ensure all Helm charts are up to date.
- Verify Kubernetes cluster accessibility and resource availability.
- Check for errors in ArgoCD deployment logs.

## Additional Resources
- [TBD]

