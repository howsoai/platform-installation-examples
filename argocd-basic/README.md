# Installation Example: ArgoCD Installation for Howso Platform

## Overview

This guide demonstrates deploying the Howso Platform using ArgoCD, a GitOps tool for Kubernetes. It emphasizes the use of ArgoCD's Helm chart capabilities to deploy the Howso Platform along with its dependent charts.

This documentation covers basic ArgoCD usage for deploying the Howso Platform. It is not a comprehensive guide to all ArgoCD features.



## Install ArgoCD

To get a basic deployment of ArgoCD, run the following commands:

```sh
# https://github.com/argoproj/argo-cd/releases/latest
kubectl apply -k argocd-basic/manifests/argocd/
```

> Note, since detailed ArgoCD installation instructions are beyond the scope of these examples - the above kustomize installation wraps up an ArgoCD installation and the configuration to use the traeffik ingress that is part of the k3d cluster. 

Make sure the ArgoCD server is running before proceeding.  
```sh
watch kubectl get po -A
```

## Login to the argocd

From a terminal with the argocd cli installed - the below instructions will get the initial pw and login.  The cli will be used to add a repo - and monitor the app deployments.

```sh
initial_argocd_pw=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd --insecure --grpc-web login argocd.local.howso.com  --username admin --password $initial_argocd_pw
echo "Log into argocd at https://argocd.local.howso.com with username admin and password $initial_argocd_pw"
```
> Note argocd ingress can be tricky to get working.  If you have trouble, you can port-forward to the argocd server (`kubectl -n argocd port-forward svc/argocd-server 8080:80`) and use http://localhost:8080.

## Apply the CRD

Argocd uses projects to limit access to kubernetes resources.  The Howso Platform uses a CRD, a cluster level component.  Installing this seperately, allows the rest of the components to be installed in a project with only namespace-level permissions. 

To extract and apply the CRD directly, use the following command.
```sh
helm template oci://registry.how.so/howso-platform/stable/howso-platform --show-only templates/crds/trainee-crd.yaml | kubectl apply -f -
```


## Add the Chart registry to ArgoCD
See the [prerequisites](../prereqs/README.md#accessing-the-howso-platform-helm-registry) for information on how to get the credentials to access the Howso Platform Helm registry.
```sh
argocd repo add registry.how.so --type helm --name replicated --username youremail@example.com --password <your-license-id> --enable-oci
```

## Create datastore secrets

See the explanation in [basic installation](../helm-basic/README.md#create-datastore-secrets) for more details.

```sh
# Minio
kubectl create secret generic platform-minio --from-literal=rootPassword="$(openssl rand -base64 20)" --from-literal=rootUser="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
# Postgres
kubectl create secret generic platform-postgres-postgresql --from-literal=postgres-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
# Redis
kubectl create secret generic platform-redis --from-literal=redis-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
```


## Install Argocd Project and Application

```sh
kubectl apply -f argocd-basic/manifests/argocd-project.yaml
kubectl apply -f argocd-basic/manifests/argocd-apps.yaml
```

Check via the UI - or the CLI, that the ArgoCD project and application are created and healthy.

```sh
argocd app list
```

<img src="../assets/argocd-success.png" width="300">
