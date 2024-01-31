# Helm Installation for Howso Platform on OpenShift

## Introduction
This guide covers how the Howso Platform installation may change to deploy in an OpenShift environments.  It demonstrates both additional configuration within the datastore components to accomodate the security policies of OpenShift, and also how to seperate out the CRD installation from the main chart installation, which can be helpful in environments where the installation is done with only namespace-level permissions. 

Ensure you have completed the [pre-requisites](../prereqs/README.md) before proceeding, and have a Kubernetes cluster running, with a howso namespace, and are logged into the Helm registry.

```sh
# pre-requisites TLDR
# Create CRC OpenShift environment
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
kubectl create namespace howso
```

### Apply the CRD

Howso Platform uses a CRD.  This is the only cluster level component that is a requirement of the platform.  Installing this seperately, allows the rest of the installation to take place with only namespace-level permissions.
To extract and apply the CRD directly, use the following command.
```sh
helm template oci://registry.how.so/howso-platform/stable/howso-platform --show-only templates/crds/trainee-crd.yaml | kubectl apply -f -
```

This command uses helm template to generate the necessary CRD manifest from the Howso Platform Helm chart and applies it using kubectl.


### Create datastore secrets

See the explanation in [basic installation](../helm-basic/README.md#create-datastore-secrets) for more details.

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

Howso Platform (install last - when all other components are ready).  Time to install will vary depending on network and resources.  
```
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values helm-openshift/manifests/howso-platform.yaml
```

> **Note** the howso-platform chart is installed with _skip: true_ under _CustomResourceDefinitions_. Since it was installed in a previous [step](#apply-the-crd).

Check the status of the pods in the howso namespace, as they come online (CTRL-C to exit).
```
watch kubectl -n howso get po 
```

Setup a test user and environment using the [instructions here](../common/README.md#create-test-environment)