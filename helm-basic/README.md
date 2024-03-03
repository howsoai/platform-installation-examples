# Helm Online Installation for Howso Platform

## Introduction
This guide details the process of deploying the Howso Platform using Helm in a non-air-gapped Kubernetes environment.
This example emphasizes a straightforward installation process for environments with direct internet access, making minimal configuration changes to the default Helm charts.  It is recommended to confirm that you can setup a basic environment before making any customizations.

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding, and have a Kubernetes cluster running, with a howso namespace, and the argocd cli installed.   

### Prerequisites TLDR
Not your first run-through?  Apply the following to get up and running quickly. 
```sh
# prerequisites TLDR
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

### Create datastore secrets 
The datastore Helm charts installed and used by Howso Platform will need random passwords generated before they start.  The charts, in their default configuration, will create these credentials directly as part of Kubernetes secret resources.  However it is not an approach that should be taken in a production environment for the following reasons:   

- There are circumstances where random secrets managed by Helm can be unstable (change when you don't expect them to).  Though (if configured to do so) Helm will lookup the existing value, and try to keep the secret the same when upgrading a release, tools like ArgoCD, that do not directly install with the Helm cli, rather template out the resources and apply them directly, will not necessarily have the same behavior. 
- It is harder to avoid the secrets being stored in places they shouldn't be, like in a repository used for gitops.
- It is also a common requirement to have these secrets managed by different tooling i.e. Hashicorp Vault, or Azure Key Vault. 

These examples will create the secrets out-of-band, as a separate step from the main installation, and then configure the chart to look for these pre-existing secrets.  This is superior to the default behavior, but is mainly done to cleanly separate the secrets management step to delineate where an organizations own policies and procedures should be applied.

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


### Install component charts 

Minio
```
helm install platform-minio oci://registry.how.so/howso-platform/stable/minio --namespace howso --values helm-basic/manifests/minio.yaml --wait
```

NATS
```
helm install platform-nats oci://registry.how.so/howso-platform/stable/nats --namespace howso --values helm-basic/manifests/nats.yaml --wait
```

Postgres
```
helm install platform-postgres oci://registry.how.so/howso-platform/stable/postgresql --namespace howso --values helm-basic/manifests/postgres.yaml --wait
```

Redis
```
helm install platform-redis oci://registry.how.so/howso-platform/stable/redis --namespace howso --values helm-basic/manifests/redis.yaml --wait
```

Howso Platform (install last - when all other components are ready).  Time to install will vary depending on network and resources.  
```
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values helm-basic/manifests/howso-platform.yaml
```

Check the status of the pods in the howso namespace, as they come online (CTRL-C to exit).
```
watch kubectl -n howso get po 
```

Setup a test user and environment using the [instructions here](../common/README.md#login-to-the-howso-platform).