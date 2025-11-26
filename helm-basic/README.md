# Helm Online Installation for Howso Platform

## Introduction

This guide details the process of deploying the Howso Platform using Helm in a non-air-gapped Kubernetes environment.
This example emphasizes a straightforward installation process for environments with direct internet access, using the built-in infrastructure services included in the Howso Platform chart. It is recommended to confirm that you can setup a basic environment before making any customizations.

For deployments using external Bitnami/MinIO charts, see the [helm-external-charts](../helm-external-charts/README.md) guide.

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding, and have a Kubernetes cluster running, with a howso namespace, and are logged into the Helm registry.

### Prerequisites TLDR

Not your first run-through?  Apply the following to get up and running quickly. 
```sh
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

## Installation

### Install Howso Platform Chart

The Howso Platform chart includes all infrastructure services by default. The [minimal configuration](./manifests/howso-platform.yaml) specifies the Replicated container registry and parent domain name (matching the one setup in our [hosts file](../prereqs/README.md#setup-hosts)). The registry credentials are automatically injected into the chart via your customer-specific Helm registry.

```
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --wait --timeout 20m
```

Time to install may vary significantly depending on network speed and resources. The `--wait --timeout 20m` flags ensure Helm waits for all pods to be ready; built-in services may take 10-15 minutes to fully initialize on first deployment.

### Monitor Deployment

You can monitor the status of pods as they come online (CTRL-C to exit):

```
watch kubectl -n howso get po
```

### Next Steps

Once all pods are running, set up a test user and Python client environment using the [instructions here](../common/README.md#login-to-the-howso-platform).