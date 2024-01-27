# Kots Existing Cluster - Air-gapped Installation for Howso Platform 

## Introduction
This guide details the process of deploying the Howso Platform using Replicated (KOTS)[https://kots.io/] into an existing Air-gapped Kubernetes cluster.  This approach wraps the Howso Platform into a single installable unit; it also provides a UI for updating, configuring, and troubleshooting the platform. 

With an air-gapped installation, there is a seperate step to download the installation media, which is then moved into the air-gapped environment.

Further details about aspects of the KOTS installation process are in the non-air-gapped [guide](../kots-existing-cluster/README.md).

Ensure you have completed the [pre-requisites](../prereqs/README.md) before proceeding, and have a Kubernetes cluster running, with a howso namespace, the kubectl kots plugin installed.

```sh
# pre-requisites TLDR
# Have your license file available on the local filesystem 
# install the kots cli https://kots.io/install/
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

### Download container images

Download an air-gap bundle as per the [instructions here](../container-images/README.md#download-air-gap-bundle).

> Note the KOTS cli bundles can also be downloaded, and moved into the air-gapped environment.  This is not covered in this guide.

## Install Certmanager

Certmanager is used to manage the TLS certificates for the Howso Platform, and is a requirement of KOTS installations.  

```sh
# https://cert-manager.io/docs/installation/ 
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
```

Make sure the cert-manager pods are ready before proceeding.  
```sh
watch kubectl get po -n cert-manager
```

> Note - installing cert-manager in an air-gapped environment is outside the scope of this guide, but a basic process might involve pulling the images indicated in the manifest, pushing to a local registry, editing the cert-manager.yaml file to point to images in a local registry, and deploying the update manifest.

## Check Local Registry

The k3d cluster used in these examples is configured to include a local registry.  In this example we'll use the [kots cli](https://kots.io/kots-cli/) - which will upload images from the air-gap bundle to the registry as part of the installation.  Change the install params to use your own registry in non-local environments. 

> Note registry-localhost was set up as a loopback host entry in the [prerequisites](../prereqs/README.md) - it should resolve to the registry container setup by k3d when the cluster was created. 

Confirm connectivity to the local registry with:

```sh
curl -s http://registry-localhost:5000/v2/_catalog | jq .
```
> If the above command fails - troubleshoot your container engine setup, and ensure k3d was installed correctly. 

## Install Howso Platform with KOTS 

This example will show a CLI driven install.  The KOTS UI can also be used, use `kubectl kots install --namespace howso howso-platform` to initiate the UI driven install.


With your license available at `~/howso-platform-license.yaml`, and your air-gapped bundle available at ~/2024.1.0.airgap - you can install the Howso Platform using the following command:


```sh
kubectl kots install howso-platform --skip-preflights \
                     --namespace howso --no-port-forward \
                     --registry-username reguser --registry-password pw \
                     --kotsadm-registry registry-localhost:5000 --skip-registry-check \
                     --kotsadm-namespace tests --airgap-bundle ~/2024.1.0.airgap \
                     --license-file  ~/howso-platform-license.yaml \
                     --shared-password kotspw --wait-duration 20m \
                     --config-values kots-existing-cluster-airgap/manifests/kots-howso-platform.yaml
```

- The `--skip-preflights` flag is used to skip the preflight checks - which will likely raise issues for local environments - though do not ignore for production deployments.
- The `--no-port-forward` flag is used to prevent the KOTS CLI from port forwarding the KOTS admin screen post installation.

Check the status of the pods in the howso namespace, as they come online (CTRL-C to exit).
```sh
watch kubectl get po -n howso
```

If you need to additionally configure the Howso Platform - you can bring up the KOTS admin screen with the following command:

```sh
# Use the --shared-password from the install command above
kubectl kots admin-console -n howso
```

Setup a test user and environment using the [instructions here](../common/README.md#login-to-the-howso-platform).