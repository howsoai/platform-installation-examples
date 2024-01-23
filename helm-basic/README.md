# Helm Non-Airgap Installation for Howso Platform
- [Helm Non-Airgap Installation for Howso Platform](#helm-non-airgap-installation-for-howso-platform)
  - [Introduction](#introduction)
    - [Create datastore secrets](#create-datastore-secrets)
    - [Install component charts](#install-component-charts)


## Introduction
This guide details the process of deploying the Howso Platform using Helm in a non-airgapped Kubernetes environment.
This documentation focuses on deploying the Howso Platform using Helm, emphasizing a straightforward installation process for environments with direct internet access.

Ensure you have completed teh [pre-requisites](../prereqs/README.md) before proceeding.


### Create datastore secrets 
The datastores will need random passwords generated before they start.  Though the  charts can create these credentials directly, there are circumnstances where random secrets managed by helm can be unstable (change when you don't expect them to, etc).  It is better practice to create them out-of-band, and then configure the chart to look for these pre-existing secrets. 

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

Check the status of the pods in the howso namespace (CTRL-C to exit)
```
watch kubectl -n howso get po 
```

Setup a test user and environment using the [instructions here](../common/README.md#Create-Test-Environment)