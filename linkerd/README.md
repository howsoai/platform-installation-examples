# Linkerd 

## Introduction
Linkerd is a popular service mesh for Kubernetes, and is a CNCF project.  If mTLS is required between all components of Howso Platform - though it is possible to configure this all manually - the recommendation is to use a well supported service mesh such as Linkerd.  This guide will show how to install Linkerd into a local Kubernetes cluster, and then how to configure the Howso Platform to use it. 

Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly.

```sh
# pre-requisites TLDR
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

## Install Linkerd
Linkerd is a full featured tool - this guide will just touch on installing it, with Helm.  The [linkerd cli](https://linkerd.io/2/getting-started/) is optional, but simplifies accessing the Linkerd dashboard, and other features.  Refer to the [Linkerd documentation](https://linkerd.io/2/overview/) for up to date install information and troubleshooting.

Add the Linkerd Helm repository
```sh
helm repo add linkerd https://helm.linkerd.io/stable
```

The CRDs are installed via a seperate chart
```sh
helm upgrade --install --namespace linkerd --create-namespace linkerd-crds linkerd/linkerd-crds --wait
```

Linkerd needs a trusted root certificate to be provided. The [step](https://smallstep.com/docs/step-cli/) tool is used to create the root and intermediate certificate.

```sh
step certificate create root.linkerd.cluster.local linkerd-ca.crt linkerd-ca.key --profile root-ca --no-password --insecure
step certificate create identity.linkerd.cluster.local linkerd-issuer.crt linkerd-issuer.key --profile intermediate-ca --not-after 8760h --no-password --insecure --ca linkerd-ca.crt --ca-key linkerd-ca.key
```

The following chart provides the main linkerd control plane components.
```sh
helm upgrade --install --namespace linkerd --set-file identityTrustAnchorsPEM=linkerd-ca.crt --set-file identity.issuer.tls.crtPEM=linkerd-issuer.crt --set-file identity.issuer.tls.keyPEM=linkerd-issuer.key linkerd-control-plane linkerd/linkerd-control-plane --wait
```

Optionally - the linkerd-viz chart can be installed to provide a dashboard for the service mesh. 
```sh
helm upgrade --install --namespace linkerd-viz --create-namespace linkerd-viz linkerd/linkerd-viz --wait
```

To run the dashboard (port-forwarded locally)
```
# You may wish to background this process with & or run it in a seperate terminal
linkerd viz dashboard
```


## Annotating the Howso Platform

By default linkerd will not involve itself in the Howso Platform traffic.  By annotating the Howso Platform namespace (default howso) - linkerd will automatically inject the sidecar proxy into all pods and establish mTLS between them. 

Annotate the namespace
```sh
kubectl annotate namespaces howso linkerd.io/inject=enabled
```


### NATS
NATS Message queue is heavilly used within the Howso Platform.  The NATS traffic is not automatically recognized by Linkerd (as it uses a server-speaks-first first protocol).  To enable Linkerd to recognize NATS traffic, the NATS service and server(s) needs to be annotated, as being an opaque port.

> Note this does not skip NATS traffic from the proxy - it just informs Linkerd that it should be proxied even though it doesn't automatically recognize it. 

Since we've installed via Helm - we'll update the installed NATS service to include the `config.linkerd.io/opaque-ports="4222"` annotation - 

The new [values file](./manifests/nats.yaml) includes the annotations. 

```sh
helm upgrade platform-nats oci://registry.how.so/howso-platform/stable/nats --namespace howso --values linkerd/manifests/nats.yaml --wait
```

> Note - Kubernetes Jobs are complicated by side-car based service meshes, as the (long lived) proxy side-car, can interfere with the job completion being registered if it doesn't also terminate.  All jobs in the Howso Platform include extra shutdown commands that explicitly terminate any proxy sidecar as the job completes.  Nothing extra is required to enable this functionality, and you should not exclude Jobs from the service mesh. 

> Note - NATS traffic will not appear 
linkerd viz edges -n howso po


## Network Policies

With Linkerd installed, and the Howso Platform annotated - proxied pod traffic that is not explicitly allowed will be denied. Every pod has a sidecar proxy - we can use network polcies to explicily only allow the Linkerd meshed traffic at the CNI level.

Check out the [network policy ingress manifests](./manifests/network-policy.yaml) before applying. The approach is as follows: 
- A default deny ingress policy is added
- All linkerd control plane traffic (label linkerd.io/control-plane-ns: linkerd) is allowed.  This label is on both the linkerd's own components as well as the components with sidecar proxies. This network policy allows all linkerd sidecar traffic to take place. 
- Services that accept ingress traffic into the cluster are whitelisted.

```sh
kubectl apply -f linkerd/manifests/network-policy.yaml -n howso
```

