# Kots Existing Cluster - Air-gapped Installation for Howso Platform 

> Note - unless constrained to installing on VMs (which is an option for KOTS installs, though these examples use an existing cluster), it is recommended to install the Howso Platform via the Replicated hosted Helm charts and not the KOTS installer.

## Introduction

This guide details the process of deploying the Howso Platform using Replicated [KOTS](https://kots.io/) into an existing Air-gapped Kubernetes cluster.  This approach wraps the Howso Platform into a single installable unit; it also provides a UI for updating, configuring, and troubleshooting the platform. 

With an air-gapped installation, there is a separate step to download the installation media which is then moved into the air-gapped environment.

Further details about aspects of the KOTS installation process are in the non-air-gapped [guide](../kots-existing-cluster/README.md).

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding, and have a Kubernetes cluster running, with a howso namespace, the kubectl kots plugin installed.


### Prerequisites TLDR

Not your first run-through?  Apply the following to get up and running quickly. 
```sh
# Have your license file available on the local filesystem 
# install the kots CLI https://kots.io/install/
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

## Steps

### Download Howso Platform container images

Download an air-gap bundle as per the [instructions here](../container-images/README.md#download-air-gap-bundle).

> Note the KOTS CLI bundles can also be downloaded, and moved into the air-gapped environment.  This is not covered in this guide.


### Download KOTS Admin container images

Download the kotsadm container images either via the [Howso Customer Portal](https://portal.howso.com) alongside the Howso Platform air-gap bundle, or from the [KOTS release page](https://github.com/replicatedhq/kots/releases).

i.e.
```sh
wget https://github.com/replicatedhq/kots/releases/download/$(kubectl kots version -o json | jq -r .latestVersion)/kotsadm.tar.gz -O ~/kotsadm.tar.gz
```

> Note:  The command substitution in the wget above ensures the kots plugin version (`kubectl kots version`) matches the container bundle version.


### Install Cert-manager

Cert-manager is a **requirement** for KOTS-driven installations (but not Helm based installs).

```sh
# https://cert-manager.io/docs/installation/ 
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
```

Make sure the cert-manager pods are ready before proceeding.  
```sh
watch kubectl get po -n cert-manager
```

> Note - installing cert-manager in an air-gapped environment is outside the scope of this guide.


### Check Local Registry

The k3d cluster used in these examples is configured to include a local registry.  We'll use the [kots cli](https://kots.io/kots-cli/) - to upload images from the air-gap bundle to the registry as part of the installation.  

> Note registry-localhost was set up as a loopback host entry in the [prerequisites](../prereqs/README.md) - it should resolve to the registry container setup by k3d when the cluster was created. 

Confirm connectivity to the local registry with:

```sh
curl -s http://registry-localhost:5000/v2/_catalog | jq .
```
> If the above command fails - troubleshoot your container engine setup, and ensure k3d was installed correctly. 


### Install Howso Platform with KOTS 

This example will show a CLI-driven install.  The KOTS UI can also be used, use `kubectl kots install --namespace howso howso-platform` to initiate the UI-driven install.

To use the following commands _as-is_ - download your license and make it available at `~/howso-platform-license.yaml`, your kotsadm container bundle at `~/kotsadm.tar.gz` and your air-gapped bundle available at `~/2024.4.0.airgap`


Push the kotsadm images to the local registry.

```sh
kubectl kots admin-console push-images ~/kotsadm.tar.gz registry-localhost:5000/howso \
            --registry-username reguser --registry-password pw --namespace howso \
            --skip-registry-check
```
> Note.  The howso namespace is included in the registry location above, but not in the next command.

Push the Howso Platform images to the local registry & complete the installation.

```sh
kubectl kots install howso-platform --skip-preflights \
                     --namespace howso --no-port-forward \
                     --registry-username reguser --registry-password pw \
                     --kotsadm-registry registry-localhost:5000 --skip-registry-check \
                     --kotsadm-namespace howso --airgap-bundle ~/2024.4.0.airgap \
                     --license-file  ~/howso-platform-license.yaml \
                     --shared-password kotspw --wait-duration 20m \
                     --config-values kots-existing-cluster-airgap/manifests/kots-howso-platform.yaml
```

Note: For a secured non-local registry, change the registry params (--registry-username/--registry-password/--kotsadm-registry) to match your environment. 

Check the status of the pods in the howso namespace as they come online (CTRL-C to exit).
```sh
watch kubectl get po -n howso
```


### Test the installation

Set up a test user and Python client environment using the [instructions here](../common/README.md#login-to-the-howso-platform).

If you need to additionally configure the Howso Platform - you can bring up the KOTS admin screen with the following command:
```sh
kubectl kots admin-console -n howso
```

> Note: You'll need the `--shared-password` from the install command above.
