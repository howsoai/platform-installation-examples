# Helm Installation for Howso Platform on OpenShift

## Introduction
This guide covers how the Howso Platform installation may be configured for deploying into an OpenShift environment.  It demonstrates the additional configuration to accommodate the security policies of OpenShift.  It also separates the CRD installation from the main chart installation, which can be helpful in environments where the installation is done with only namespace-level (OpenShift Project) permissions.

The Howso Platform chart includes **built-in infrastructure services** (Postgres, Valkey, NATS, VersityGW) configured to work with OpenShift's Security Context Constraints (SCCs). This is the **recommended approach** for OpenShift deployments.

**For deployments** requiring external Bitnami/MinIO charts, this guide also covers the legacy 5-chart installation approach. See [Option 2: External Charts Mode](#option-2-external-charts-mode) below.

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding, have an OpenShift cluster running, with a howso project, and are logged into the Helm registry.


### Prerequisites TLDR

Not your first run-through?  Apply the following to get up and running quickly. 
```sh
# Create OpenShift Local environment
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
kubectl create namespace howso # oc new-project howso
```

### OpenShift deployment considerations

OpenShift is a Kubernetes-based platform that has additional security features and policies.  Most of the configurations that it will insist on are solid best practices, and, in general, Howso Platform takes them as its default.  The following is provided to explain the reason for Helm chart configuration that differs for OpenShift and to help guide any additional work required to get the dependent charts working in an OpenShift environment.

#### Security Context Constraints

Security Context Constraints (SCCs) are an OpenShift feature similar to the native [Kubernetes Pod Security Standards/Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/), but more fine-grained.  They allow OpenShift administrators to define constraints around the Linux permissions for Kubernetes pod processes. The default `restricted` SCC, which all pods will run with unless specifically assigned different permissions, will trip up default configurations of many Helm charts.  The following are some of the key constraints: 


##### MustRunAsRange

The MustRunAsRange SCC forces pods in a constrained OpenShift project (namespace) to run as a Linux user within an id range assigned to that namespace; the exact range will vary.  In the absence of a specific `runAsUser` configuration, OpenShift will inject a suitable user into the pod spec at the time of deployment.

Doing so then requires that deployed pods can work with any arbitrary user ID, unknown in advance, unrelated to any user permissions in the Dockerfile, and compatible with any volume configuration.  It also means that any existing runAsUser configuration will likely be incompatible and rejected at installation.

##### readOnlyRootFilesystem

OpenShift will add the readOnlyRootFilesystem to all pod securityContexts.  This sometimes trips up containers that cache some incidental data, etc, without properly configuring a emptyDir volume (for example).


##### runAsNonRoot

Though best avoided, there are enough layers to Kubernetes/container's security, that it is not uncommon for containers to run as the 0/root user.  OpenShift will reject these configurations, and in the case of NATS, that means turning off the NATS-Box utility.


## Common Steps (Both Modes)

### Apply the CRD

The Howso Platform application uses Custom Resource Definitions (CRDs) to run workloads.  Aside from the namespace itself, these CRDs are the only cluster-level components that are required to install the platform.  Installing them separately allows the rest of the installation to take place with only namespace-level permissions.

To extract and apply the CRD directly, use the following command:
```sh
helm template oci://registry.how.so/howso-platform/stable/howso-platform --show-only 'templates/crds/*.yaml' | kubectl apply -f -
```

This command uses Helm's template functionality to generate the necessary CRD manifest from the Howso Platform Helm chart and pipes it directly to kubectl to apply.

---

## Option 1: All-in-One Mode (Recommended)

This approach uses the Howso Platform chart with built-in infrastructure services configured for OpenShift SCCs.

### Install Howso Platform Chart

The Howso Platform chart includes all infrastructure services with OpenShift-compatible security contexts. The [OpenShift-specific configuration](./manifests/howso-platform-openshift.yaml) ensures compatibility with the `restricted` SCC:

```sh
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-openshift/manifests/howso-platform-openshift.yaml
```

**What gets deployed:**
- Howso Platform services (API, UMS, SMS, Worker, Operator, UI, PyPI)
- Built-in Postgres (with TLS, OpenShift-compatible security contexts)
- Built-in Valkey (with TLS, OpenShift-compatible security contexts)
- Built-in NATS (with mTLS, OpenShift-compatible security contexts)
- Built-in VersityGW object storage (with HTTPS, OpenShift-compatible security contexts)
- Certificate generator (automatic cert creation and renewal)

**Note:** The built-in services are configured to work with OpenShift's `MustRunAsRange` and other SCCs. The chart automatically handles user ID constraints and read-only root filesystem requirements.

---

## Option 2: External Charts Mode

This approach uses separate Helm charts for infrastructure services (Bitnami Postgres, Redis, MinIO, NATS) with OpenShift-specific configurations.

**For detailed guidance on external charts**, see the [helm-external-charts](../helm-external-charts/README.md) guide.

### Create datastore secrets

External charts require pre-created secrets. See the [helm-external-charts guide](../helm-external-charts/README.md#create-datastore-secrets) for detailed explanation.

```sh
# Minio
kubectl create secret generic platform-minio --from-literal=rootPassword="$(openssl rand -base64 20)" --from-literal=rootUser="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
# Postgres
kubectl create secret generic platform-postgres-postgresql --from-literal=postgres-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
# Redis
kubectl create secret generic platform-redis --from-literal=redis-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
```

### Install component charts 

Minio
```
helm install platform-minio oci://registry.how.so/howso-platform/stable/minio --namespace howso --values helm-openshift/manifests/minio.yaml --wait
```

NATS
```
helm install platform-nats oci://registry.how.so/howso-platform/stable/nats --namespace howso --values helm-openshift/manifests/nats.yaml --wait
```

Postgres
```
helm install platform-postgres oci://registry.how.so/howso-platform/stable/postgresql --namespace howso --values helm-openshift/manifests/postgres.yaml --wait
```

Redis
```
helm install platform-redis oci://registry.how.so/howso-platform/stable/redis --namespace howso --values helm-openshift/manifests/redis.yaml --wait
```
See [Redis licensing update](../../redis-license-update.md) for important version information.

Howso Platform (install last - when all other components are ready).  Time to install will vary depending on network and resources.  
```
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values helm-openshift/manifests/howso-platform.yaml
```

> **Note** the howso-platform chart is installed with _skip: true_ under _CustomResourceDefinitions_. Since it was installed in a previous [step](#apply-the-crd).

---

## Verification (Both Modes)

Check the status of the pods in the howso namespace, as they come online (CTRL-C to exit).
```
watch kubectl -n howso get po
```

Verify pods are running with appropriate OpenShift SCCs:
```sh
# Check which SCC each pod is using
kubectl -n howso get po -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.openshift\.io/scc}{"\n"}{end}'
```

All pods should show the `restricted` SCC, confirming they comply with OpenShift security policies.

Setup a test user and environment using the [instructions here](../common/README.md#create-test-environment)