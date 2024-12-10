# Installation Example: Argo Workflows for Howso Platform

## Introduction

This guide details how to add [Argo Workflows](https://argoproj.github.io/workflows/) integration to your Howso Platform installation. Argo Workflows is a container-native workflow engine for Kubernetes that enables additional workflow automation capabilities within the Howso Platform.

> Note: Workflows integration is available in Howso Platform 2024.12.0 and later as an early access feature.

### Prerequisites

This guide will add the Argo Workflows integration to an existing Howso Platform installation.  Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly.  See [here](../common/README.md#basic-helm-install) for a quick start.


## Steps

### Install Argo Workflows

Add the Argo Helm repository:
```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

Take a look at the [manifests](./manifests/argo-workflows.yaml) for the Argo Workflows configuration.  Most of the custom configuration is will be created by the Howso Platform chart - via a configmap (platform-configmap-workflows-controller), this values file references this configmap.

Ingress is enabled, so that the Argo Workflows UI will be available at https://argo-workflows.local.howso.com. 

Install Argo Workflows using Helm:

```sh
helm install argo-workflows argo/argo-workflows \
  --namespace howso \
  --values argo-workflows/manifests/argo-workflows.yaml
```

Since Howso Platform is not yet configured to use Argo Workflows, the config map is not available.  The installed Argo Workflows components (controller and server) will not start.

```sh
kubectl get pods -n howso -l app.kubernetes.io/instance=argo-workflows
```

### Enable Workflows in Howso Platform

Take a look at the [workflow configuration](./manifests/howso-platform.yaml) for the Howso Platform. The workflow feature and the jobs sub-feature are enabled. Update your existing Howso Platform installation to enable workflows:

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

Argo Workflows is used to enable features in the Howso Platform, such as the UI Synthesizer.  The UI can help with visibility into the workflows running in the cluster, but is not required for the Howso Platform to function, and is not used to directly run workflows.


### Run the UI Synthesizer feature


The UI Synthesizer feature is available in the Howso Platform UI.  It uses Argo Workflows under the hood to synthesize small datasets, uploaded via the browser.

#### Steps

- Set a password and login using the [instructions here](../common/README.md#login-to-the-howso-platform).
- Create a new project and give it a name, such as `ui-synthesizer`.
- Click into the project, and look for the Jobs section.  Click the `+ Create new` button then `synthesizer job` from the dropdown.
- You will need a dataset to upload.  Grab [iris](https://raw.githubusercontent.com/mwaskom/seaborn-data/master/iris.csv) and save locally.
- Give any name to the synthesizer job, such as `iris-synthesizer`.
- In the Add New Data section, select or drag and drop the iris dataset.
- Click Create.  The job will run, first inferring the features from the dataset.
- For this `iris` example, if any features show a warning, click configure and deselect `Sensitive` and update.
- Click `Next Step` then `Run`.
> Note: Both the infer feature attributes and the synthesizer job run as workflows in the cluster - view them with `kubectl get workflows -n howso`.

Click through the stats, synthesized dataset and validation results.

