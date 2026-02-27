# Helm Installation with External Charts

## Introduction

This guide details the process of deploying the Howso Platform using external charts for infrastructure services (Postgres, Redis, NATS, MinIO).

When to use this approach:
- You have existing Bitnami/MinIO chart deployments you want to integrate with
- You require specific versions or configurations not available in built-in services
- You need to gradually migrate from a previous Howso Platform installation
- Your organization has standardized on specific Helm charts for infrastructure

For simpler deployments, see the [helm-basic](../helm-basic/README.md) guide which uses built-in services included in the Howso Platform chart.

> Note for Existing Installations: If you're currently using external datastores, including Helm charts, there's no urgent need to migrate. Using external datastores continues to be fully supported.

This guide deploys Howso Platform in a non-air-gapped Kubernetes environment with direct internet access.

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding, and have a Kubernetes cluster running, with a howso namespace, and are logged into the Helm registry.

### Prerequisites TLDR

Not your first run-through?  Apply the following to get up and running quickly. 
```sh
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

## Steps

### Create datastore secrets 

The datastore Helm charts used by the Howso Platform require random credentials generated before they initialize.  The charts, in their default configuration, will create these credentials directly as part of Kubernetes' secret resources.  However, this is not an approach that should be taken in a production environment for the following reasons:   

- There are circumstances where random secrets managed by Helm can be unstable (change when you don't expect them to).  However if configured to do so, Helm will look-up an existing value, and try to keep the secret the same when upgrading a release; tools like Argo CD, that do not directly install with the Helm CLI (rather they template out the resources and apply them directly) will not necessarily have the same behavior. 
- It is harder to avoid the secrets being stored in places they shouldn't be, like in a repository used for gitops.
- It is also a common requirement to have these secrets managed by different tooling i.e. Hashicorp Vault, or Azure Key Vault. 

As such, all examples in this documentation will create the secrets out-of-band, as a separate step from the main installation, and then configure the chart to look for these pre-existing secrets.  This is superior to the default behavior but is not done to be prescriptive, but to cleanly separate the secrets management step to delineate where an organization's own policies and procedures should be applied.

Minio
```
kubectl create secret generic platform-minio --from-literal=rootPassword="$(openssl rand -base64 20)" --from-literal=rootUser="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
```

Postgres
```
kubectl create secret generic platform-postgres-postgresql --from-literal=postgres-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
```

Redis
```
kubectl create secret generic platform-redis --from-literal=redis-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
```


### Add Helm Repositories

NATS requires adding the official Helm repository:

```sh
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo update
```

### Install Helm Charts

Now install the Helm charts.  It is encouraged to check the [values manifest files](./manifests/) for each chart, to see the minimal configuration applied to each.

> Note. Using the same release names is important, so that the default configuration of the Howso Platform chart can find the other components.


#### Minio

[Bitnami MinIO](./manifests/minio.yaml) is deployed in standalone mode with pre-created secrets.
```
helm install platform-minio oci://registry-1.docker.io/bitnamicharts/minio --namespace howso --values helm-external-charts/manifests/minio.yaml --wait
```

#### NATS

NATS with [Jetstream](./manifests/nats.yaml) enabled is a mandatory component.
```
helm install platform-nats nats/nats --namespace howso --values helm-external-charts/manifests/nats.yaml --wait
```

#### Postgres

[Existing secrets](./manifests/postgres.yaml) are used as described [above](#create-datastore-secrets)
```
helm install platform-postgres oci://registry-1.docker.io/bitnamicharts/postgresql --namespace howso --values helm-external-charts/manifests/postgres.yaml --wait
```

#### Redis

[Read replicas](./manifests/redis.yaml) are scaled down for a smaller/basic installation. See [Redis licensing update](../redis-license-update.md) for important version information.
```
helm install platform-redis oci://registry-1.docker.io/bitnamicharts/redis --namespace howso --values helm-external-charts/manifests/redis.yaml --wait
```

#### Howso Platform

Howso Platform is installed last - when all other components are ready. This installation uses [values-external-all.yaml](./manifests/values-external-all.yaml) to disable built-in services and configure connections to the external charts deployed above. The [howso-platform.yaml](./manifests/howso-platform.yaml) file configures the Replicated container registry and parent domain name (matching the one setup in our [hosts file](../prereqs/README.md#setup-hosts)). The registry credentials are injected into the chart in your customer-specific Helm registry.

```
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-external-charts/manifests/values-external-all.yaml \
  --values helm-external-charts/manifests/howso-platform.yaml
```

The `values-external-all.yaml` file disables all built-in services and points to the external chart service names (e.g., `platform-postgres-postgresql`, `platform-redis-master`, `platform-minio`, `platform-nats`). See the [values file](./manifests/values-external-all.yaml) for detailed configuration and upgrade path documentation.

Time to install may vary significantly depending on network speed and resources -so the above install command avoids waiting.  Instead check the status of the pods in the howso namespace, as they come online (CTRL-C to exit).

```
watch kubectl -n howso get po 
```

Set up a test user and Python client environment using the [instructions here](../common/README.md#login-to-the-howso-platform).
