# Securing Howso Platform 

## Examples

- [Prerequisites](../prereqs/README.md)
---
- [Linkerd and Network Policies](../linkerd/README.md)
- [Container Scanning](../container-images/README.md)
- [Custom Ingress](../custom-ingress-cert/README.md)


## Introduction

Howso Platform installed on-prem via Helm charts requires several security considerations. Firstly, it is necessarily a shared security model between the Howso Platform application and the operators of the Kubernetes cluster.

Kubernetes is a highly customizable platform, and many aspects that are part of the application security (i.e., establishing TLS between components) are best done at the framework level, using components such as a service mesh. As such, Howso Platform, when distributed as a Helm chart, cannot independently claim to be secure by default – it is the wrong layer for that requirement. It is however designed to fit into a secure environment, and this section will cover the main topics to consider.


## Encrypted Communication

Howso Platform consists of several services, data stores, and a message queue (NATS). When using the default **built-in services**, TLS/mTLS is enabled automatically between all internal components. When using **external charts** without additional configuration, traffic between components may be unencrypted—in which case communication should be considered within a trusted network, or additional TLS configuration applied. 

These docs will cover two approaches:

- Using a service mesh to automatically provide mTLS between all components
- Manually configuring TLS to NATS and external data stores

> Note: In a Kubernetes cluster, depending on the Container Network Interface (CNI) used, traffic between nodes may be encrypted. Overlay networks, such as Calico or Weave, can be configured to encrypt traffic between nodes. This is a separate concern from the application-level encryption discussed here, but may be a relevant consideration when assessing the security posture of the cluster and its applications. 

For information about ingress traffic TLS see the [Ingress Certs](#ingress-certs) section.

### Service Mesh

Service mesh can be installed to automatically provide mTLS between all communicating endpoints. Typically, organizations with larger Kubernetes teams will likely have a service mesh that they use.

With multiple data stores and a message queue, the Howso Platform can be complex to configure communication paths individually. A service mesh provides a single, uniform way to secure communication between all components, alongside other benefits such as observability and traffic control.  It is therefore the recommended approach for securing communication between the Howso Platform components.

See the [Linkerd and Network Policies](../linkerd/README.md) section for an example of using a service mesh with the Howso Platform.


### Manually configuring TLS between components

It is possible to manually configure TLS between the Howso Platform and its data stores and message queue. 

Within the Howso Platform [values file](../common/README.md#howso-platform-helm-chart-values), under the `datastores` and `nats` sections, is the configuration for setting up TLS connections.  To configure TLS communication to external data stores (i.e. an AWS RDS Postgres, or S3) override the values in this section when installing the chart.

If configuring TLS to the data stores and message queue charts, then corresponding configuration will be required in the NATS, minio, Redis, and Postgres chart installations.

> Though possible, setting up TLS manually between Howso Platform and all backend charts is considered an advanced use-case.  To do this efficiently will involve setting up Kubernetes Public Key Infrastructure (PKI) tools i.e. cert-manager; alongside significant configuration of the Howso Platform and backend charts.  It is recommended instead to use a service mesh for providing mTLS.  Reach out to Howso Support for further guidance.

### Automatic Certificate Rotation

When using the built-in cert-generator (which creates certificates for internal platform components), certificates are renewed automatically via a CronJob. However, **pods do not automatically reload certificates** when secrets are updated, which can lead to certificate expiry failures.

**Solution: Install Stakater Reloader**

[Stakater Reloader](https://github.com/stakater/Reloader) is a Kubernetes controller that watches for changes in ConfigMaps and Secrets, automatically triggering rolling restarts of pods that reference them.

**Installation:**

```bash
# Add Stakater Helm repository
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update

# Install Reloader (namespace-scoped recommended)
helm install reloader stakater/reloader -n <platform-namespace> \
  --set reloader.watchGlobally=false
```

**Configuration:**

After installing Reloader, annotate your Deployments and StatefulSets to watch specific certificate secrets:

```bash
# Example: API service watches its NATS client certificate
kubectl annotate deployment platform-api-v3 -n <namespace> \
  secret.reloader.stakater.com/reload="platform-api-v3-nats-client-tls"

# Example: PostgreSQL watches both server and client certificates
kubectl annotate statefulset platform-postgres -n <namespace> \
  secret.reloader.stakater.com/reload="platform-postgres-server-tls,platform-postgres-client-tls"
```

**How it works:**

1. cert-generator CronJob renews certificates (based on configured schedule and expiry threshold)
2. Certificate secrets are updated with new certificate data
3. Reloader detects the secret data change within seconds
4. Affected pods are automatically restarted via rolling update (zero downtime)
5. Pods load fresh certificates on startup

**Verification:**

```bash
# Check Reloader is running
kubectl get pods -n <namespace> | grep reloader

# Watch Reloader logs during certificate rotation
kubectl logs -n <namespace> deployment/reloader-reloader --tail=50 -f

# Expected output during rotation:
# Changes detected in 'platform-postgres-server-tls' of type 'SECRET' in namespace 'howso';
# updated 'platform-postgres' of type 'StatefulSet' in namespace 'howso'
```

**Certificate Configuration:**

Certificate duration and rotation frequency are configured in the Helm values:

```yaml
jobs:
  certGenerator:
    # How long certificates are valid
    newCertDuration: "2160h"    # 90 days (production default)

    # Renew when this much time remains
    expiryThreshold: "720h"     # 30 days (production default)

    # How often to check for renewal
    schedule: "0 3 * * 0"       # Weekly on Sundays at 3am (production)
```

For development/testing with shorter certificate lifetimes, adjust these values and increase the CronJob frequency accordingly.

> **Note:** Reloader is particularly important when using short-lived certificates for testing or when running in environments where certificate rotation happens frequently (e.g., dev clusters with 1-hour certificates).


## Encrypted Storage

Howso Platform itself does not directly use Persistent Volumes, though the infrastructure services (whether built-in or deployed as external charts) will create Persistent Volume Claims (PVCs) for Postgres, Redis/Valkey, object storage, and NATS.  In the documented examples, these PVCs will use the default storage class of the Kubernetes cluster, though they can be configured to use a specific storage class. 

Using a Storage Class that meets your security requirements is considered to be on the Kubernetes operator's side of the shared security model. 


## Security Scanning 

See the [Container Scanning](../container-images/README.md#howsos-approach) section for information on scanning the Howso Platform container images, and Howso Platform's approach to container security.



## Ingress Certs

See the [Custom Ingress](../custom-ingress-cert/README.md) section for information on using custom ingress certificates with the Howso Platform.
