# Installation Example: Argo Workflows for Howso Platform

## Introduction

This guide details how to add [Argo Workflows](https://argoproj.github.io/argo-helm) support to your Howso Platform installation. Argo Workflows is a container-native workflow engine for Kubernetes that enables additional workflow automation capabilities within the Howso Platform.

### Prerequisites

This guide will add the Argo Workflows integration to an existing Howso Platform installation.  Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly.  See [here](../common/README.md#basic-helm-install) for a quick start.


## Steps

### Install Argo Workflows

Add the Argo Helm repository:
```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

Take a look at the [manifests](./manifests/argo-workflows.yaml) for the Argo Workflows configuration.  There are a few essentially changes, most of the custom configuration is achieved through the Howso Platform configuration - via a configmap (platform-configmap-workflows-controller) that is created by the Howso Platform, which is referenced in these values.

Install Argo Workflows using Helm:

```sh
helm install argo-workflows argo/argo-workflows \
  --namespace howso \
  --values argo-workflows/manifests/argo-workflows.yaml
```

### Enable Workflows in Howso Platform

Take a look at the [workflow configuration](./manifests/howso-platform.yaml) for the Howso Platform. The workflow feature and the jobs sub-feature are enabled. Update your existing Howso Platform installation to enable workflows:

```sh
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --values argo-workflows/manifests/howso-platform.yaml
```

### Verify Installation

Check that the Argo Workflows pods are running:

```sh
kubectl get pods -n howso -l app.kubernetes.io/name=argo-workflows
```

Make sure all pods show as Running before proceeding. You should see pods for the workflow controller and server.

Verify that workflow templates are available:

```sh
kubectl get workflowtemplates -n howso
```


### Accessing the Argo Workflow UI

The Argo Workflows UI is available at `https://argo-workflows.local.howso.com`.  As server mode is enabled, no authentication is required in this configuration.


### Run the UI Synthesizer feature


The UI Synthesizer feature is available in the Howso Platform UI.  It uses Argo Workflows under the hood to synthesize small datasets, uploaded via the browser.

#### Steps

- Setup a test user and environment using the [instructions here](../common/README.md#login-to-the-howso-platform).
- Create a new ... 

