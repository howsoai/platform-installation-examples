# Kots Existing Cluster Installation for Howso Platform 

> Note - unless constrained to installing on VMs (which is an option for KOTS installs, though these examples use an existing cluster), it is recommended to install the Howso Platform via the Replicated hosted Helm charts and not the KOTS installer.

## Introduction

This guide details the process of deploying the Howso Platform using Replicated (KOTS)[https://kots.io/] into an existing Kubernetes cluster.  This approach wraps the Howso Platform into a single installable unit; it also provides a UI for updating, configuring, and troubleshooting the platform. 

This formulation can be a convenient way to get started with the Howso Platform - but will not provide the same levers to control the deployments as Helm installs.  As such, if you have detailed Kubernetes requirements - you may not be able to meet them with this approach. 

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding, and have a Kubernetes cluster running with a howso namespace and the kubectl kots plugin installed.


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

### Install Cert-manager

Cert-manager is used to manage the TLS certificates for the Howso Platform.  With the KOTS-driven install - it is a **requirement**; the Howso Platform KOTS implementation will use cert-manager to create a certificate authority for the platform, and configure TLS for all the communication channels between the Howso Platform, its data stores, and message queue. 

> The install is straightforward, but as it uses many Kubernetes features (CRDs, webhooks) it may require extra configuration for certain Kubernetes clusters (i.e. Open Shift).  

```sh
# https://cert-manager.io/docs/installation/ 
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
```

Make sure the cert-manager pods are ready before proceeding.  
```sh
watch kubectl get po -n cert-manager
```

### Install the Howso Platform with KOTS 

For this example choose either the UI-driven or a CLI-driven install approach.  The CLI-driven install is useful for scripting and environments where the UI is not initially available (configuring KOTS-installed applications is much more straightforward via the UI).  The CLI-driven install uses a configuration file to set the initial password and parent domain name.


#### Install via the KOTS UI

For the UI-driven install, with the license file to hand, run the following command: 

```sh
kubectl kots install --namespace howso howso-platform
```

- Set a password for the admin user (for the KOTS configuration screens, distinct from the platform-admin user).  
- (When up) Access the KOTS admin screen at http://localhost:8800 - and use the password to login.
- Upload the license file.
- Continue (using the _internet install_ link at the bottom - if you have an air-gapped enabled license)
- From the Configuration screen, note the initial platform-admin password, and enter `local.howso.com` in the _Parent Domain Name_ field.
- Disable _Enable Internal TLS_ which is not supported for the k3d traefik ingress.
- Continue > Deploy (Preflight checks will likely raise issues for local environments - though do not ignore for production deployments)
- When the status on the _Dashboard_ screen becomes _Ready_ - proceed to [test the install](#test-the-installation).

> Note. If you are running on an OpenShift cluster and performing a KOTS installation (the recommended approach would be a [Helm install](../helm-openshift/README.md)) - make sure to select the _Configure Platform for OpenShift_ checkbox on the _Configuration_ screen.  From the cli, you can add a value of 1 to a key _openshift_enabled_ in the config file.


#### Install via the KOTS CLI

Alternatively, the following installation command assumes your license is downloaded from the [Howso Customer Portal](https://portal.howso.com) and is available at `~/howso-platform-license.yaml`.

```sh
kubectl kots install howso-platform --skip-preflights \
                     --namespace howso --no-port-forward \
                     --license-file  ~/howso-platform-license.yaml \
                     --shared-password kotspw --wait-duration 20m \
                     --config-values kots-existing-cluster/manifests/kots-howso-platform.yaml
```

- The `--skip-preflights` flag is used to skip the preflight checks - which will likely raise issues for local environments - though do not ignore for production deployments.
- The `--no-port-forward` flag is used to prevent the KOTS CLI from port forwarding the KOTS admin screen post-installation.

Check the status of the pods in the howso namespace, as they come online (CTRL-C to exit).
```sh
watch kubectl get po -n howso
```


### Test the installation

Set up a test user and environment using the [instructions here](../common/README.md#login-to-the-howso-platform).

If you need to additionally configure the Howso Platform - you can bring up the KOTS admin screen with the following command:
```sh
kubectl kots admin-console -n howso
```

> Note: You'll need the `--shared-password` from the install command above for CLI driven installs, or the password you were initially prompted for in the UI driven install.
