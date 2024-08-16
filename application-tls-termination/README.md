To fully confirm that the traffic is encrypted, you can use a [debug container](#verifying-tls-traffic-for-kubernetes-services) and capture the traffic between the ingress and the sidecar container. TLS Termination at the Application (not Ingress)

## Introduction 
Typically Ingress controllers terminate TLS connections at the edge of the cluster. If your security posture requires traffic from the ingress to the application also be encrypted, this guide will explain how, using a fully working local example. 

There are two main aspects to the solution.  The Ingress controller must be configured to send encrypted traffic to the relevant Howso Platform services, and the Howso Platform services must be configured to accept this encrypted traffic.

> Note: Using a [service mesh](../linkerd/README.md) is another way to ensure all traffic (not just ingress to application) is encrypted.  Service mesh work as a cluster level framework that then require no (or minimal) application changes to encrypt all traffic.

## TLS Sidecar

To accept encrypted traffic, the Howso Platform Helm chart can be configured with the `podTLS.enabled` value to switch on TLS sidecar containers.  These are nginx containers that run in the same pod as an application configured to terminate a TLS connection from the Ingress controller and forward traffic to the main application container (which is now local traffic that doesn't leave the machine).

The sidecar containers will need to be supplied with a server certificate to use for the TLS handshake with the Ingress controller.  The ingress will need to be configured to trust these certificates, by placing either the certificates or a root signing certificate in its trust store.

> Note: It may also be acceptable to disable the Ingress certificate verification check, lessening the security of the connection (potentially opening up a man-in-the-middle style attack), but still encrypting the traffic.


## Ingress controller Configuration

There are Ingress controller objects created by the Howso Platform Helm chart, but for extended configuration, such as TLS termination at the application, the Ingress controller objects will often need to be created manually, as Ingress controllers are often quite different in their configuration.  This K3d example using Traefik will show how to create Ingress rules (using Traefik CRDs) to send encrypted traffic, to the ports of the sidecar containers, for the API, UI, PyPI and UMS services. 

### Some extra background

[Ingress controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) act as a reverse proxy to access services running in a Kubernetes cluster.  Howso Platform relies on the Ingress controller to route incoming traffic to its service.  Ingress controllers are typically configured by Ingress objects which layout the traffic routing rules.  The Howso Platform Helm chart will create these objects when it is installed.

> Note: The approach to configuring Ingress controllers is changing in Kubernetes, with the Ingress object type being frozen, in favor of the [Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/).  Support for the Gateway API is increasing, but it is still less common.  Howso Platform does not yet support the Gateway API.

With many implementations of Ingress controller, with a variety of different features, the Ingress object has not managed to provide a consistent approach outside of the basic routing features.  As a result, many Ingress controllers have their own CRD types, which are more flexible, and can handle more complex routing rules.  It is also common for Ingress controllers to have a large number of bespoke annotations that can be used against the built in Ingress object.

As a result, the Howso Platform Helm chart is not able to switch on 'Ingress to application' TLS universally for all Ingress controllers.  There are a couple (contour & nginx) that will work just by using the `podTLS.enabled` value, but for most, the Ingress object will need to be disabled, and appropriate Ingress rules created manually.

In this example, we will use Traefik, which comes with the k3d cluster.  It is a common Ingress controller in its own right, and serves as a good extended example as configuring it to send TLS traffic to the back end application is not possible with the built in Ingress object.

> Note: Other Ingress controllers will differ in their configuration, but the [manifests](./manifests) will give a good example of the specific information about paths, ports and service names.


## Setup Steps

### Prerequisites
.
Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly. See [here](../common/README.md#basic-helm-install) for a quick start.

Install the [step](https://smallstep.com/docs/step-cli/) certificate tool. 

### Configure Howso Platform TLS sidecars

The values file for the howso-platform chart will need to turn on the podTLS feature ...
```yaml
podTLS:
  enabled: true 
```
... and globally turn Ingress object creation off.

```yaml
ingress:
  enabled: false
```

> Note: Howso Platform release 2024.8.0 is required to globally disable Ingress object creation.  If you are using an older version, you will need to manually delete the Ingress objects created by the Helm chart.

From your installation of the [helm basic example](../helm-basic/README.md), update the chart with these [manifests](./manifests/howso-platform.yaml) additions. 

```sh
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values helm-basic/manifests/howso-platform.yaml --values custom-ingress/manifests/howso-platform.yaml 
```

### Creating sidecar server Certificates

Without further intervention, some of the Howso Platform pods will no longer be able to start as they expect to find secrets containing certificates that don't yet exist.

In the next steps we'll create certificates for a root CA and each required service using the `step` CLI tool, then create the corresponding Kubernetes secrets.

> Note: This example uses a root CA so that the Ingress controller just needs to trust a single certificate.  There is an existing platform root CA secret (platform-ca) that is created by the platform-cert-generation jobs, which also creates certificates for use by the UMS to provide an Oauth authorization server, and a default ingress cert.  It is possible to extract and reuse this root ca, but this example will focus solely of the TLS termination certificates.

For each service the following will be needed for the certs.
- A SAN name that matches the cluster service address that is the expected hostname in the TLS handshake.
- A Reference to the root CA certificate and key.
- A profile suitable for a server certificate.
- No passphrase is used, this would require a further step in the sidecar to accept a passphrase and decrypt the key.


> Note: Mechanisms for renewing the certificate are beyond the scope of this example. 

#### Root CA

First, create the root CA:

```sh
step certificate create root-ca root-ca.crt root-ca.key \
    --profile root-ca \
    --no-password --insecure
```

Create Root ca secret:
```sh
kubectl create secret generic platform-app-tls-ca \
  --from-file=ca.crt=root-ca.crt \
  -n howso
```

#### Platform PyPI Server

Create the certificate for the PyPI server:

```sh
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

```sh
kubectl -n howso create secret tls platform-pypi-server-tls --key platform-pypi-server-tls.key --cert platform-pypi-server-tls.crt
```

#### Platform UMS Server

Create the certificate for the UMS server:

```sh
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

```sh
kubectl -n howso create secret tls platform-ums-server-tls --key platform-ums-server-tls.key --cert platform-ums-server-tls.crt
```

#### Platform UI (v2) Server

Create the certificate for the UI:

```sh
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

```sh
kubectl -n howso create secret tls platform-ui-v2-server-tls --key platform-ui-v2-server-tls.key --cert platform-ui-v2-server-tls.crt
```

#### Platform API (v3) Server

Create the certificate for the API v3 server:

```sh
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

```sh
kubectl -n howso create secret tls platform-api-v3-server-tls --key platform-api-v3-server-tls.key --cert platform-api-v3-server-tls.crt
```


### Create Ingress Resources

Take a look at the [manifests](./manifests/) for the services.  In this section we'll apply the ingress configuration service by service, and check that it is working.  If you hit issues, [turn on debug logs](#troubleshooting) in Traefik to see what is going wrong. 


#### Platform PyPI Ingress

Create the ingress resource for the platform-pypi service:

```sh
kubectl apply -f application-tls-termination/manifests/traefik-ingress-pypi.yaml
```

Hit the [PyPI](https://pypi.local.howso.com) endpoint in your browser, proceed past the certificate warning and you should see the PyPI server's landing page.

#### Confirming the TLS Termination

Check the Ready column shows 2/2 for the platform-pypi pods.
```sh
kubectl get po -l app.kubernetes.io/component=platform-pypi
```
This indicates that the pod is running two containers, the main application container and the TLS sidecar container.

Check the logs of the TLS sidecar container to confirm that it is running correctly.  It is an nginx container that is configured to terminate the TLS connection and forward the traffic to the main application container.

```sh
kubectl -n howso logs -l app.kubernetes.io/component=platform-pypi -c tls-sidecar -f
```

To fully confirm that the traffic is encrypted, you can use a [debug container](#verifying-tls-traffic-for-kubernetes-services) and capture the traffic between the ingress and the sidecar container.

### Platform UI Ingress


```sh
kubectl apply -f application-tls-termination/manifests/traefik-ingress-ui.yaml
```

Confirm that you can hit the parent domain [endpoint](https://local.howso.com), after proceeding past the certificate warning you should be redirected to the initial [Howso UI page](https://www.local.howso.com) 

### Platform API Ingress

Take a look at the [manifests](./manifests/traefik-ingress-api.yaml) for the platform-api ingress.  Apply the manifest to the cluster.

```sh
kubectl apply -f application-tls-termination/manifests/traefik-ingress-api.yaml
```

Confirm that you can hit the main API [endpoint](https://api.local.howso.com/api/v3/), after proceeding past the certificate warning you should see a 404 page.

### Platform UMS Ingress

Take a look at the [manifests](./manifests/traefik-ingress-ums.yaml) for the platform-ums ingress.  Apply the manifest to the cluster.

```sh
kubectl apply -f application-tls-termination/manifests/traefik-ingress-ums.yaml
```

Confirm that you can hit the main UMS [endpoint](https://management.local.howso.com), after proceeding past the certificate warning you should see the login page. 


### Troubleshooting

#### Traefik debug logs

Add debug logs to traefik

```sh
kubectl edit deployment traefik -n kube-system
```

Under the `- args:` section, add the following line:
```yaml
- --log.level=DEBUG
```

Tail the logs of the traefik pod to see the debug logs
```sh
kubectl -n kube-system logs -l app.kubernetes.io/name=traefik
```

#### Verifying TLS Traffic for Kubernetes Services

To fully confirm that the traffic encrypted requires capturing traffic from ingress to the tls sidecar.  A little involved, but you can do this using a debug container with network tools as follows.

Get pypi (or other service) pod name:
```sh
POD_NAME=$(kubectl get pod -n howso -l app.kubernetes.io/component=platform-pypi -o jsonpath='{.items[0].metadata.name}')
```

Launch a debug container:
```sh
kubectl debug -it -n howso $POD_NAME --image=nicolaka/netshoot --target=tls-sidecar
```

Now you're in the same network namespace as the sidecar container, with tools from the [netshoot](https://github.com/nicolaka/netshoot) image.  You can use tshark to capture traffic.

```sh
tshark -i any -n -Y "ssl or tls"
```

In a separate terminal generate traffic to the service:
```sh
curl -k https://pypi.local.howso.com/
```

Confirm TLS traffic by looking for output similar to:

```
TLSv1 Client Hello
TLSv1.2 Server Hello, Certificate, Server Key Exchange, Server Hello Done
TLSv1.2 Application Data
```
