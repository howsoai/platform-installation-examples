# Setting up Dex as an Identity Provider for Howso Platform

## Introduction

This guide details the process of deploying Dex as an identity provider and integrating it with Howso Platform as an OpenID Connect (OIDC) client.

This demonstrates a self-contained Single Sign-On (SSO) setup, where the Identity Provider (Dex) is responsible for user authentication for the application (Howso Platform).

In this example Dex takes the place of your actual Identity Provider (IdP) such as Active Directory or Okta, but shows a working system without external dependencies.

Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly.  See [here](../common/README.md#basic-helm-install) for a quick start.

## Install and Configure Dex 

Add Dex to your local hosts file

```sh
echo "127.0.0.1  dex.local.howso.com" | sudo tee -a /etc/hosts
```


Add Dex Helm repository

```sh
helm repo add dex https://charts.dexidp.io
helm repo update
```

Create a namespace for Dex.

```sh
kubectl create namespace dex
```

Before applying, take a look at the [Dex configuration](./manifests/dex.yaml).  For demonstration purposes Dex is configured with a single static user, the credentials are supplied in the values file.  This user can be used to authenticate against Dex.  Once the Howso Platform is configured as an OAuth application with Dex as the Identity Provider, it will be possible to log in to Howso Platform using these credentials.

In addition the [client](https://www.oauth.com/oauth2-servers/definitions/) is configured to represent Howso Platform in an Oauth2 with OpenID Connect flow.


Install Dex from Helm.

```sh
helm install dex dex/dex --namespace dex -f oidc/manifests/dex.yaml --wait
```

Check Dex is running.

This endpoint is the OpenID Connect discovery document, if it is accessible Dex is running.

```sh
curl -k https://dex.local.howso.com/.well-known/openid-configuration
```

You can also navigate to the Dex dashboard and hit the [Dex Login Page](https://dex.local.howso.com/auth).  You will have to accept the self signed certificate to proceed.  At this point it will display, but show an error.  This is expected, the Dex login page is expecting to be used only as part of a SSO flow.


## Configure Howso Platform

Take a look at the [config](./manifests/howso-platform.yaml) for Howso Platform.  The required endpoints are configured under the `oidc` key to point at the Dex installation.   

> Note: The configuration uses the Dex Kubernetes service DNS address (`dex.dex.svc.cluster.local`) for all endpoints except the authorize endpoint.  This is because Dex is only accessible to the Howso Platform application via the Kubernetes network (due to it using localhost, which will resolve differently from a pod in the cluster), however the users browser can hit the external address (dex.local.howso.com), but not the service.  The authorize endpoint is the one used to construct the redirect URL to dex during the Login flow.  In the case of an Identity Provider that is consistently accessible from the browser and the application, likely the case for a production setup, the same address can be used for all endpoints.

Update your Howso Platform configuration to configure OIDC with Dex as the identity provider.

```sh
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values oidc/manifests/howso-platform.yaml --wait
```

## Verification

> Note: Without [trusted TLS certificates configured](../custom-ingress-cert/README.md) Expect to hit a number of warnings, for each subdomain of Howso Platform.  Go to https://api.local.howso.com/ and https://management.local.howso.com accept those certificate warnings first.  Otherwise errors will be hidden, as those domains are accessed indirectly from pages hosted at other subdomains.  

- Access the Howso Platform UI via https://local.howso.com/.  You should be redirected to the Dex login page.

- Log in using the static user credentials (admin@example.com / password).

- Upon successful authentication, you should be redirected back to Howso Platform.


## Troubleshooting 

If you encounter any issues with the SSO setup or login process, please refer to our detailed [SSO Troubleshooting Guide](./troubleshooting.md) for assistance.
