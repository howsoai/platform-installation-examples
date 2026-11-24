# Installation Example: Argo Workflows for Howso Platform

## Introduction

This guide details how to add [Argo Workflows](https://argoproj.github.io/workflows/) integration to your Howso Platform installation. Argo Workflows is a container-native workflow engine for Kubernetes that enables additional workflow automation capabilities within the Howso Platform.

> Note: Workflows integration is available in Howso Platform 2024.12.0 and later as an early access feature.

### Prerequisites

This guide will add the Argo Workflows integration to an existing Howso Platform installation.  Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly.  See [here](../common/README.md#basic-helm-install) for a quick start.


## Steps


### Argo Workflows host entry

Add to your local hosts file

```sh
echo "127.0.0.1  argo-workflows.local.howso.com" | sudo tee -a /etc/hosts
```

### Install Argo Workflows

Add the Argo Helm repository:
```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

Take a look at the [manifests](./manifests/argo-workflows.yaml) for the Argo Workflows configuration.  Most of the custom configuration will be created by the Howso Platform chart - via a configmap (platform-configmap-workflows-controller), this values file references this configmap.

Ingress is enabled, so that the Argo Workflows UI will be available at https://argo-workflows.local.howso.com. 

Install Argo Workflows using Helm.  This guide is tested with chart version 2.0.18 (Argo Workflows v4.1.6):

```sh
helm install argo-workflows argo/argo-workflows \
  --version 2.0.18 \
  --namespace howso \
  --values argo-workflows/manifests/argo-workflows.yaml
```

Since Howso Platform is not yet configured to use Argo Workflows, the config map is not available.  The installed Argo Workflows components (controller and server) will not start.

```sh
kubectl get pods -n howso -l app.kubernetes.io/instance=argo-workflows
```

### Enable Workflows in Howso Platform

Take a look at the [workflow configuration](./manifests/howso-platform.yaml) for the Howso Platform, which enables the workflow feature. Update your existing Howso Platform installation to enable workflows:

```sh
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --values argo-workflows/manifests/howso-platform.yaml
```

Though the Argo Workflows components will eventually start, now the config map is available, you can speed up the process by restarting the pods:

```sh
kubectl delete pod -n howso -l app.kubernetes.io/instance=argo-workflows
```

### Verify Installation

Argo Workflows is now installed and enabled in Howso Platform.  The next steps are to verify the installation and then run an analyze that is offloaded to a workflow.

### Argo Workflows pods

Check that the Argo Workflows pods are running:

```sh
kubectl get pods -n howso -l app.kubernetes.io/instance=argo-workflows
```

Make sure all pods show as Running before proceeding. You should see pods for the workflow controller and server.

The Argo Workflow integration includes workflow templates that should now be installed into the cluster, verify they are available:

```sh
kubectl get workflowtemplates -n howso
```


### Accessing the Argo Workflow UI

The Argo Workflows UI is available at https://argo-workflows.local.howso.com.  Click through the certificate warning to access the UI.  As server mode is enabled, no authentication is required in this configuration.

The Howso Platform uses Argo Workflows to offload long-running Trainee tasks to their own workers.  The UI can help with visibility into the workflows running in the cluster, but is not required for the Howso Platform to function, and is not used to directly run workflows.


### Run an offloaded analyze

With workflows enabled, `analyze` on a persisted Trainee runs as a workflow from the `task-worker` template rather than in the Trainee's own worker.

#### Steps

- Set up a Python client environment using the [common setup steps](../common/README.md#create-client-environment).
- Run the following, which trains a persisted Trainee on the iris dataset and analyzes it:

```python
import pandas as pd
from howso.engine import Trainee
from howso.utilities import infer_feature_attributes

df = pd.read_csv("https://raw.githubusercontent.com/mwaskom/seaborn-data/master/iris.csv")
trainee = Trainee(features=infer_feature_attributes(df), persistence="always")
trainee.train(df)
trainee.analyze()
trainee.delete()
```

- While `analyze` runs, the workflow appears in the cluster and completes with a `Succeeded` status:

```sh
kubectl get workflows -n howso
```

