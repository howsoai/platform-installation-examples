# TLS Termination at the Application Level 

## Introduction 
Typically Ingress Controllers terminate TLS connections at the edge of the cluster. If your security posture requires that all traffic, even intra-cluster, be encrypted, you can configure the Ingress Controller to send encrypted traffic to the application. This is done by configuring the Ingress Controller to send traffic to the application over HTTPS, and configuring the application to accept HTTPS traffic.

When enabled, with the `podTLS.enabled` value, the Howso Platform chart application uses side-car nginx containers in all the pods that accept traffic from the Ingress Controller. This guide will show a local example where Ingress traffic TLS terminates at the application.

## Prerequisites
Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly. See the [TLDR](../common/README.md#basic-helm-install) for a quick start.

## Configure Applications to use TLS  

Augment the values file for the howso-platform chart to turn on the podTLS feature.
```yaml
podTLS:
  enabled: true 
```

Additionally ingress is globally turned off.  For certain ingress controllers, such as the NGINX Ingress Controller and contour, this is not necessary, and configuring podTLS will also alter the created ingress resources such that they send encrypted traffic through to the application.  In this example, using the traefik ingress controller, we will turn off the ingress controller - and manually create ingress resources.

```yaml
ingress:
  enabled: false
```

If you install the [helm basic example](../helm-basic/README.md), you can update to use the custom ingress certs with the following command - checkout the [manifests](./manifests/howso-platform.yaml) additions. 
```sh
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values helm-basic/manifests/howso-platform.yaml --values custom-ingress/manifests/howso-platform.yaml 
```

## Creating Missing Certificates

Without further intervention, the applications will not be able to start, as they expect to find secrets containing the certificates. We'll create certificates for the root CA and each required service using the `step` CLI tool, then create the corresponding Kubernetes secrets.

### Root CA

First, create the root CA:

```bash
step certificate create root-ca root-ca.crt root-ca.key \
    --profile root-ca \
    --no-password --insecure
```

### Platform PyPI Server

Create the certificate for the PyPI server:

```bash
step certificate create platform-pypi.default.svc.cluster.local platform-pypi-server-tls.crt platform-pypi-server-tls.key \
    --profile leaf \
    --not-after 2160h \
    --ca root-ca.crt \
    --ca-key root-ca.key \
    --no-password \
    --insecure \
    --san platform-pypi \
    --san platform-pypi.default.svc.cluster.local \
    --set "subject.organization=Howso Platform"
```

Create the corresponding Kubernetes secret:

```bash
kubectl -n howso create secret tls platform-pypi-server-tls --key platform-pypi-server-tls.key --cert platform-pypi-server-tls.crt
```

### Platform UMS Server

Create the certificate for the UMS server:

```bash
step certificate create platform-ums.default.svc.cluster.local platform-ums-server-tls.crt platform-ums-server-tls.key \
    --profile leaf \
    --not-after 2160h \
    --ca root-ca.crt \
    --ca-key root-ca.key \
    --no-password \
    --insecure \
    --san platform-ums \
    --san platform-ums.default.svc.cluster.local \
    --set "subject.organization=Howso Platform"
```

Create the corresponding Kubernetes secret:

```bash
kubectl -n howso create secret tls platform-ums-server-tls --key platform-ums-server-tls.key --cert platform-ums-server-tls.crt
```

### Platform UI v2 Server

Create the certificate for the UI v2 server:

```bash
step certificate create platform-ui-v2.default.svc.cluster.local platform-ui-v2-server-tls.crt platform-ui-v2-server-tls.key \
    --profile leaf \
    --not-after 2160h \
    --ca root-ca.crt \
    --ca-key root-ca.key \
    --no-password \
    --insecure \
    --san platform-ui-v2 \
    --san platform-ui-v2.default.svc.cluster.local \
    --set "subject.organization=Howso Platform"
```

Create the corresponding Kubernetes secret:

```bash
kubectl -n howso create secret tls platform-ui-v2-server-tls --key platform-ui-v2-server-tls.key --cert platform-ui-v2-server-tls.crt
```

### Platform API v3 Server

Create the certificate for the API v3 server:

```bash
step certificate create platform-api-v3.default.svc.cluster.local platform-api-v3-server-tls.crt platform-api-v3-server-tls.key \
    --profile leaf \
    --not-after 2160h \
    --ca root-ca.crt \
    --ca-key root-ca.key \
    --no-password \
    --insecure \
    --san platform-api-v3 \
    --san platform-api-v3.default.svc.cluster.local \
    --set "subject.organization=Howso Platform"
```

Create the corresponding Kubernetes secret:

```bash
kubectl -n howso create secret tls platform-api-v3-server-tls --key platform-api-v3-server-tls.key --cert platform-api-v3-server-tls.crt
```


## Create Ingress Resources

The ingress object for the platform-pypi service needs to securely route external HTTPS traffic to the internal application. It should listen for incoming requests on the standard HTTPS port 443, targeting the hostname pypi.local.howso.com. Upon receiving a request, it must terminate the SSL connection, then re-encrypt the traffic and forward it to the backend service named platform-pypi on port 8443 using HTTPS. Any incoming HTTP traffic on port 80 should be automatically redirected to HTTPS. The ingress should use the TLS certificate stored in the Kubernetes secret named platform-ingress-tls for SSL termination. All paths under the root (/) should be directed to the backend service. This configuration ensures end-to-end encryption, with SSL termination and re-encryption occurring at the ingress level, maintaining secure communication throughout the entire request lifecycle.
