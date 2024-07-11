# Setting up Dex as Identity Provider for Howso Platform

## Introduction

This guide details the process of deploying Dex as an identity provider and integrating it with Howso Platform as an OpenID Connect (OIDC) client.  This allows Howso Platform to authenticate users using Dex, demonstrating a Single Sign-On (SSO) setup, where your Identity Provider (Dex) is responsible for user authentication and many applications including Howso Platform can rely on it for user authentication. 

Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly.

```sh
# prerequisites TLDR
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
# Install the [linkerd cli](https://linkerd.io/2/getting-started/) and the certificate tool [step](https://smallstep.com/docs/step-cli/).
# Setup the Kubernetes cluster
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl -n kube-system wait --for=condition=ready --timeout=180s pod -l k8s-app=metrics-server
kubectl create namespace howso
# Create datastore secrets 
kubectl create secret generic platform-minio --from-literal=rootPassword="$(openssl rand -base64 20)" --from-literal=rootUser="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
kubectl create secret generic platform-postgres-postgresql --from-literal=postgres-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
kubectl create secret generic platform-redis --from-literal=redis-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
# Install component charts 
helm install platform-minio oci://registry.how.so/howso-platform/stable/minio --namespace howso --values helm-basic/manifests/minio.yaml --wait
helm install platform-nats oci://registry.how.so/howso-platform/stable/nats --namespace howso --values helm-basic/manifests/nats.yaml --wait
helm install platform-postgres oci://registry.how.so/howso-platform/stable/postgresql --namespace howso --values helm-basic/manifests/postgres.yaml --wait
helm install platform-redis oci://registry.how.so/howso-platform/stable/redis --namespace howso --values helm-basic/manifests/redis.yaml --wait
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values helm-basic/manifests/howso-platform.yaml --wait --timeout 20m
```


## Install and Configure Dex 

Add Dex to your local hosts file

```sh
echo "127.0.0.1  dex.local.howso.com" | sudo tee -a /etc/hosts
```


Add Dex Helm repository

```bash
helm repo add dex https://charts.dexidp.io
helm repo update
```

Create a namespace for Dex.

```bash
kubectl create namespace dex
```

Before applying, take a look at the [Dex configuration](./manifests/dex.yaml).  To demonstrate the SSO features of Howso Platform Dex is configured to have a single static user.  That user can be used to authenticate against Dex, and when Howso Platform is configured as an OAuth application with Dex as the Identity Provider, it will be possible to use this user to log into Howso Platform.

In addition the [client](https://www.oauth.com/oauth2-servers/definitions/) is configured to represent Howso Platform in an Oauth2 with OpenID Connect flow.


Install Dex from Helm.

```bash
helm install dex dex/dex --namespace dex -f oidc/manifests/dex.yaml
```

Check Dex is running.

This endpoint is the OpenID Connect discovery document, if it is accessible Dex is running.

```bash
curl -k https://dex.local.howso.com/.well-known/openid-configuration
```

You can also navigate to the Dex dashboard and hit the [Dex Login Page](https://dex.local.howso.com/auth).  You will have to accept the self signed certificate to proceed.  At this point it will display, but error.  It is configured to only be used during a login flow, so this is expected.  


## Configure Howso Platform

Take a look at the [config](./manifests/howso-platform.yaml) for Howso Platform.  the required endpoints are configured to point at the Dex installation.   

> Note: The configuraiton uses the Dex Kubernetes service DNS address (`dex.dex.svc.cluster.local`) for all endpoints except the authorize endpoint.  This is because Dex is only accessible to the Howso Platform application via the Kubernetes network (due to it using localhost, which will resolve differently from a pod in the cluster), however the users browser can hit the external address (dex.local.howso.com), but not the service.  The authorize endpoint is the one used to construct the redirect URL to dex during the Login flow.

Update your Howso Platform configuration to configure OIDC with Dex as the identity provider.

```bash
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values manifest/howso-platform.yaml  --values ../helm-basic/manifests/howso-platform.yaml --wait
```



Upgrade the Howso Platform Helm release with the OIDC configuration:


## Verification

- Access the Howso Platform UI via https://local.howso.com/.  You should be redirected to the Dex login page.

- Log in using the static user credentials (admin@example.com / password).

- Upon successful authentication, you should be redirected back to Howso Platform.
