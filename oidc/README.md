# Setting up Dex as Identity Provider for Howso Platform

## Introduction

This guide details the process of deploying Dex as an identity provider and integrating it with Howso Platform as an OpenID Connect (OIDC) client.  This allows Howso Platform to authenticate users using Dex, demonstrating a SSO setup, where your Identity Provider (Dex) is responsible for user authentication and many applications including Howso Platform can rely on it for user authentication. 

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

Add Dex to local hosts. 

```sh
127.0.0.1  dex.local.howso.com
```


Add Dex Helm repository

```bash
helm repo add dex https://charts.dexidp.io
helm repo update
```

Create a namespace for Dex

```bash
kubectl create namespace dex
```

Take a look at the [Dex configuration](./manifests/dex.yaml).  To demostrate the SSO features of Howso Platform we configure Dex to have a static user, to log in with.  Also a static client is configured to represent the Howso Platform in an Oauth2 with OpenID Connect flow.


Install Dex

```bash
helm install dex dex/dex --namespace dex -f oidc/manifests/dex.yaml
```

Check Dex is running

This endpoint is the OpenID Connect discovery document, if it is accessible Dex is running.
```bash
curl -k https://dex.local.howso.com/.well-known/openid-configuration
```

You can also navigate to the Dex dashboard and hit the (Dex Login Page)[https://dex.local.howso.com/auth].  At this point it will error, as it is used only during a login flow.  You will have to accept the self signed certificate to proceed.



## Configure Howso Platform

Update your Howso Platform Helm values file (e.g., `howso-platform-values.yaml`) with the following OIDC configuration:

```yaml
oidc:
  enabled: true
  clientID: "howso-platform"
  clientSecret: "your-client-secret-here"
  algorithm: "RS256"
  jwksEndpoint: "https://dex.local.howso.com/keys"
  authorizeEndpoint: "https://dex.local.howso.com/auth"
  tokenEndpoint: "https://dex.local.howso.com/token"
  userinfoEndpoint: "https://dex.local.howso.com/userinfo"
  scopes: "openid email profile"
```


Upgrade the Howso Platform Helm release with the OIDC configuration:

```bash
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values manifest/howso-platform.yaml  --values ../helm-basic/manifests/howso-platform.yaml --wait
```

## Verification

1. Access the Howso Platform UI.
2. You should be redirected to the Dex login page.
3. Log in using the static user credentials (admin@example.com / password).
4. Upon successful authentication, you should be redirected back to Howso Platform.

## Notes

- Ensure that your DNS is configured to resolve `dex.example.com` and `howso-platform.example.com` to your cluster's ingress.
- The example uses a static password for simplicity. In a production environment, you should configure Dex to use a more appropriate authentication backend.
- The client secret should be securely generated and managed. Consider using Kubernetes secrets for sensitive data.
- Adjust the URLs in the configuration to match your actual deployment addresses.
