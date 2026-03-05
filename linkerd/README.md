# Linkerd 

## Introduction
Linkerd is a popular service mesh for Kubernetes, and is a CNCF project.  If mTLS is required between all components of Howso Platform - though it is possible to configure this all manually - the recommendation is to use a well supported service mesh such as Linkerd.  This guide will show how to install Linkerd into a local Kubernetes cluster, and then how to configure the Howso Platform to use it. 

Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly.  See [here](../common/README.md#basic-helm-install) for a quick start.


## Install Linkerd
Linkerd is a feature-rich tool - this guide will just touch on installing it, with Helm.  The [linkerd cli](https://linkerd.io/2/getting-started/) is optional, but simplifies accessing the Linkerd dashboard, and other features.  Refer to the [Linkerd documentation](https://linkerd.io/2/overview/) for up to date install information and troubleshooting.

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

alternatively natively with kubectl ..
```sh
kubectl -n linkerd-viz port-forward svc/web 8084:8084
```
...and navigate to http://localhost:8084


## Annotating the Howso Platform

By default linkerd will not involve itself in the Howso Platform traffic.  By annotating the Howso Platform namespace (default howso) - linkerd will automatically inject the sidecar proxy into all pods and establish mTLS between them.

Annotate the namespace
```sh
kubectl annotate namespaces howso linkerd.io/inject=enabled
```

### Handling Infrastructure Service Ports

Howso Platform's built-in infrastructure services (Postgres, Valkey, NATS, ObjectStore) use application-level TLS managed by cert-manager by default. Linkerd's proxy cannot layer its mTLS on top of these already-encrypted connections — attempting to do so causes connection failures (e.g. `[SSL: UNEXPECTED_EOF_WHILE_READING]`). NATS additionally uses a server-speaks-first protocol that Linkerd cannot automatically detect.

There are two approaches:

**Option A: Skip infrastructure ports (default — keep app-level TLS)**

Exclude infrastructure ports from the Linkerd proxy using `skip-inbound-ports` / `skip-outbound-ports`. Traffic on these ports bypasses the proxy and relies on the existing application-level TLS. All other traffic remains fully meshed.

**Option B: Disable builtin TLS (let the mesh handle encryption)**

Disable application-level TLS on the built-in services and let Linkerd provide encryption. Apply the `values-builtin-notls.yaml` overlay (shipped alongside `values.yaml` in the chart) when installing:

```sh
helm install howso-platform ./howso-platform \
  -f values-builtin-notls.yaml \
  [other values files...]
```

You can also set the annotations via Helm values (`builtin.<service>.podAnnotations` and `builtin.<service>.service.annotations`) instead of patching after install. This gives Linkerd full L7 visibility on datastore traffic. See the chart's `values-builtin-notls.yaml` for the complete set of values.

---

The rest of this section demonstrates **Option A** (skip ports).

Patch infrastructure statefulsets to skip inbound proxy on their service ports:
```sh
kubectl -n howso patch statefulset platform-nats --type merge \
  -p '{"spec":{"template":{"metadata":{"annotations":{"config.linkerd.io/skip-inbound-ports":"4222"}}}}}'
kubectl -n howso patch statefulset platform-postgres --type merge \
  -p '{"spec":{"template":{"metadata":{"annotations":{"config.linkerd.io/skip-inbound-ports":"5432"}}}}}'
kubectl -n howso patch statefulset platform-valkey --type merge \
  -p '{"spec":{"template":{"metadata":{"annotations":{"config.linkerd.io/skip-inbound-ports":"6379"}}}}}'
kubectl -n howso patch statefulset platform-objectstore --type merge \
  -p '{"spec":{"template":{"metadata":{"annotations":{"config.linkerd.io/skip-inbound-ports":"9000"}}}}}'
```

Patch all deployments to skip outbound proxy for infrastructure ports:
```sh
INFRA_PORTS="4222,5432,6379,9000"
for deploy in $(kubectl -n howso get deployment -o name); do
  kubectl -n howso patch "$deploy" --type merge \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"config.linkerd.io/skip-outbound-ports\":\"$INFRA_PORTS\"}}}}}"
done
```

If your platform is installed with **external charts** (separate Helm releases for each service), also upgrade the NATS release to include the annotations. The [values file](./manifests/nats.yaml) includes the annotations for the service and statefulset.

> Note: If you haven't already added the NATS Helm repository, run: `helm repo add nats https://nats-io.github.io/k8s/helm/charts/`

```sh
helm upgrade platform-nats nats/nats --namespace howso --values linkerd/manifests/nats.yaml --wait
```

> Note - Kubernetes Jobs are complicated by side-car based service meshes, as the (long lived) proxy side-car, can interfere with the job completion being registered if it doesn't also terminate.  All jobs in the Howso Platform include extra shutdown commands that explicitly terminate any proxy sidecar as the job completes.  Nothing extra is required to enable this functionality, and you should not exclude Jobs from the service mesh. 


### Restart the Howso Platform

Linkerd won't inject the sidecar into existing pods.  Restart the Howso Platform to have the sidecar injected. 

```sh
kubectl delete po --all -n howso
watch kubectl -n howso get po # Note the extra containers in the READY column
```

## Test the Howso Platform

Setup a test user and environment using the [instructions here](../common/README.md#login-to-the-howso-platform).

Observe the traffic in the Linkerd dashboard.  The dashboard will show the traffic between the Howso Platform components.

> Note - Infrastructure service traffic (NATS, Postgres, Valkey, ObjectStore) bypasses the proxy and will not appear in the Linkerd graphs. Since NATS is the main inter-pod communication channel, the graphs do not give a complete picture of traffic flow. You can confirm that meshed pods have secured edges with:
```sh
linkerd viz edges -n howso po
```


## Network Policies

Every pod in the namespace has a Linkerd sidecar proxy. This proxy will control and secure the network traffic of all appropriately annotated pods - securing all explicitly configured ports, and denying access to all other traffic. 
 To further protect the network, this time at the CNI (Container Network Interface) level- we can also use network polcies (similar to a firewall rule) to explicily only allow only traffic between these linkerd pods. 

> Note not all Kubernetes network configurations support network policies.  The default CNI for k3d (flannel) does not, but k3d (k3s in a container) uses kube-router, a [network policy controller](https://docs.k3s.io/networking#network-policy-controller) to enforce network policies.

Check out the [network policy ingress manifests](./manifests/network-policy.yaml) before applying. The approach is as follows: 
- A [default deny](./manifests/network-policy-default-deny.yaml) ingress policy is added
- All linkerd control plane traffic (label linkerd.io/control-plane-ns: linkerd) is allowed.  This label is on both the linkerd's own components as well as the components with sidecar proxies. This network policy allows all linkerd sidecar traffic to take place. 
- Services that accept ingress traffic into the cluster are whitelisted.

First apply the default deny policy.  This will configure the CNI to block all namespaced traffic.
```sh
kubectl apply -f linkerd/manifests/network-policy-default-deny.yaml -n howso
```

Confirm that you can no longer access the Howso Platform from outside the cluster i.e. https://management.local.howso.com.  The validation tests will also fail. 

```sh
python -m howso.utilities.installation_verification
```

Then apply the proxy side-car and ingress whitelist policies.

```sh
kubectl apply -f linkerd/manifests/network-policy.yaml -n howso
```

Both the Howso Platform and the validation tests should now pass.