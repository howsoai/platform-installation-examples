# Kots Existing Cluster Installation for Howso Platform 

## Introduction
This guide details the process of deploying the Howso Platform using Replicated (KOTS)[https://kots.io/] into an existing Kubernetes cluster.  This approach wraps the Howso Platform into a single installable unit; it also provides a UI for updating, configuring, and troubleshooting the platform. 


This formulation can be a convenient way to get started with the Howso Platform - but will not provide the same levers to control the deployments as Helm installs.  As such, if you have detailed Kubernetes requirements - you may not be able to meet them with this approach. 


```sh
# pre-requisites TLDR
# Have your license file available on the local filesystem 
# install the kots cli https://kots.io/install/
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

## Install Certmanager

Certmanager is used to manage the TLS certificates for the Howso Platform.  With the KOTS driven install - it is a requirement; the Howso Platform KOTS implementation will use Certmanager to create a certificate authority for the platform, and configure up TLS for all the communication channels between the Howso Platform, its datastores, and message queue. 

> The install is straightforward, but as it uses many Kubernetes features (CRDs, webhooks) may require extra configuration for certain Kubernetes clusters (i.e. Open Shift).  

```sh
# https://cert-manager.io/docs/installation/ 
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
```

Make sure the cert-manager pods are ready before proceeding.  
```sh
watch kubectl get po -n cert-manager
```

## Install Howso Platform using KOTS 

This example will show either an entirely UI driven install, or a CLI driven install.  The CLI driven install is useful for scripting, and for environments where the UI is not available.  The CLI driven install uses a configuration file to set the initial password, and the parent domain name.


### Install the Howso Platform using the KOTS UI

There is a UI driven install approach, that (with the license file to hand) you can initiate with the following command: 

```sh
kubectl kots install --namespace howso howso-platform
```

- Set a password for the admin user (for the KOTS configuration screens).  
- (When up) Access the KOTS admin screen at http://localhost:8800 - and use the password to login.
- Upload the license file.
- Continue (using the internet install)
- From the Configuration screen, note the initial platform-admin password, and enter `local.howso.com` in the _Parent Domain Name_ field.
- Disable _Enable Internal TLS_ which is not supported for the k3d traefik ingress.
- Continue > Deploy (Preflight checks will likely raise issues for local environments - though do not ignore for production deployments)
- When the status on the _Dashboard_ screen becomes _Ready_ - Procceed to [test the install](../common/README.md#login-to-the-howso-platform).


### Install the Howso Platform using the KOTS CLI

With your license available at `~/howso-platform-license.yaml` - you can install the Howso Platform using the following command:

```sh
kubectl kots install  --skip-preflights --namespace howso  --license-file  ~/howso-platform-license.yaml --shared-password kotspw --config-values kots-existing-cluster/manifests/kots-howso-platform.yaml howso-platform --wait-duration 20m --no-port-forward
```

If you need to configure the Howso Platform - you can bring up the KOTS admin screen with the following command:

```sh
# Use the --shared-password from the install command above
kubectl kots admin-console -n howso
```

Setup a test user and environment using the [instructions here](../common/README.md#login-to-the-howso-platform).