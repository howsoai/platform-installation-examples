# Installation Example: ArgoCD Installation for Howso Platform

## Overview

This guide demonstrates deploying the Howso Platform using ArgoCD, a GitOps tool for Kubernetes. It emphasizes the use of ArgoCD's Helm chart capabilities to deploy the Howso Platform along with its dependent charts.

This documentation covers basic ArgoCD usage for deploying the Howso Platform. It is not a comprehensive guide to all ArgoCD features.



## Install ArgoCD

To get a basic deployment of ArgoCD, run the following commands:

```
# https://github.com/argoproj/argo-cd/releases/latest
kubectl apply -k argocd-basic/manifests/
```

> Note on incress


## server insecure

## Login
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
argocd --insecure --grpc-web account update-password --current-password Cdo1pJIxhmyvEQaZ --new-password Password#1


## Apply the CRD

Argocd uses projects to limit access to kubernetes resources.  The Howso Platform uses a CRD, a cluster level component.  Installing this seperately, allows the rest of the components to be installed in a project with only namespace-level permissions. 

To extract and apply the CRD directly, use the following command.
```sh
helm template oci://registry.how.so/howso-platform/stable/howso-platform --show-only templates/crds/trainee-crd.yaml | kubectl apply -f -
```