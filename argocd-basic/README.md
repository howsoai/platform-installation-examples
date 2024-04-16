# Installation Example: Argo CD Installation for Howso Platform

## Overview

This guide demonstrates deploying the Howso Platform using Argo CD, a GitOps tool for Kubernetes. It emphasizes the use of Argo CD's Helm chart capabilities to deploy the Howso Platform along with its dependent charts.

This documentation covers basic Argo CD usage for deploying the Howso Platform. It is not a comprehensive guide to Argo CD features.

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding, and have a Kubernetes cluster running, with a howso namespace, and the argocd CLI installed. 

### Prerequisites TLDR

Not your first run-through?  Apply the following to get up and running quickly. 
```sh
# install argocd CLI https://argo-cd.readthedocs.io/en/stable/cli_installation/
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
# add local.howso.com pypi|api|www|management|argocd.local.howso.com to /etc/hosts 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

## Steps

### Install Argo CD

To get a [basic deployment of Argo CD](https://github.com/argoproj/argo-cd/releases/latest), run the following command:

```sh
kubectl apply -k argocd-basic/manifests/argocd/
```

> Note: Since detailed Argo CD installation instructions are beyond the scope of these examples - the above kustomize installation wraps up an Argo CD installation and the configuration to use the traefik ingress that is part of the k3d cluster. 

Make sure the Argo CD server is running before proceeding.  
```sh
watch kubectl get po -A
```

### Login to Argo CD 

The example will use the Argo CD CLI tool to add a Helm repository and to monitor the app deployments.

From a terminal with the `argocd` CLI installed - the below instructions will get the initial credentials and login cli.

```sh
initial_argocd_pw=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd --insecure --grpc-web login argocd.local.howso.com  --username admin --password $initial_argocd_pw
echo "Log into argocd at https://argocd.local.howso.com with username admin and password $initial_argocd_pw"
```

Try and access the UI in a browser (accept the certificate warning) and login with the credentials provided.

> Note: Argo CD ingress can be tricky to get working.  If you have trouble, you can port-forward to the argocd server (`kubectl -n argocd port-forward svc/argocd-server 8080:80`) and use http://localhost:8080 to access the UI.


### Apply the CRD

Argo CD uses [projects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/) to limit access to Kubernetes resources for applications.  The Howso Platform uses CRDs, a cluster-level component.  Installing this separately allows the rest of the components to be installed in a project with only [namespace-level permissions](./manifests/argocd-project.yaml).

To extract and apply the CRD directly, use the following command:
```sh
helm template oci://registry.how.so/howso-platform/stable/howso-platform --show-only 'templates/crds/*.yaml' | kubectl apply -f -
```

### Add the Chart registry to Argo CD

See the [prerequisites](../prereqs/README.md#accessing-the-howso-platform-helm-registry) for information on how to get credentials to access the Howso Platform Helm registry.

> Note: The helm registry is of type `oci` - so the command includes the `--enable-oci` flag.

```sh
argocd repo add registry.how.so --type helm --name replicated --username youremail@example.com --password <your-license-id> --enable-oci
```

### Create datastore secrets

See the explanation in [basic installation](../helm-basic/README.md#create-datastore-secrets) for more details.

```sh
# Minio
kubectl create secret generic platform-minio --from-literal=rootPassword="$(openssl rand -base64 20)" --from-literal=rootUser="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
# Postgres
kubectl create secret generic platform-postgres-postgresql --from-literal=postgres-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
# Redis
kubectl create secret generic platform-redis --from-literal=redis-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
```


### Install Argocd Project and Application

If you open up the [project manifest](manifests/argocd-project.yaml), you will see that it is configured to use the `howso` namespace.  Since the CRD was installed separately, and the Howso Platform [application manifest](manifests/argocd-howso-platform-app.yaml) is configured to skip CRD installation, the project does not need to give any cluster-scoped permissions.

> Note: In the [Argo CD Application manifests](manifests/argocd-required-apps.yaml) configuration provided in values files during a direct Helm Install is embedded into the Application manifests.  

```sh
kubectl apply -f argocd-basic/manifests/argocd-project.yaml
kubectl apply -f argocd-basic/manifests/argocd-required-apps.yaml
kubectl apply -f argocd-basic/manifests/argocd-howso-platform-app.yaml
```

Check via the [UI](https://argocd.local.howso.com) - or the CLI, that the Argo CD project and application are created and healthy.

```sh
argocd app list # Check the Argo CD app status
kubectl get po -n howso # Check the pod status
```

<img src="../assets/argocd-success.png" width="300">

Set up a test user and Python client client environment using the [instructions here](../common/README.md#login-to-the-howso-platform).