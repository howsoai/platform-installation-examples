# Installation Example: Helm Airgap Installation 

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


## Steps 