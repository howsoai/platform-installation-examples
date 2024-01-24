# Helm Airgap Installation for Howso Platform
- [Helm Airgap Installation for Howso Platform](#helm-airgap-installation-for-howso-platform)
  - [Introduction](#introduction)
    - [Setting up the local registry](#setting-up-the-local-registry)
    - [Create datastore secrets](#create-datastore-secrets)
    - [Pull component charts](#pull-component-charts)
    - [Install component charts](#install-component-charts)


## Introduction
This guide details the process of deploying the Howso Platform using Helm in a airgapped Kubernetes environment.

This is an example - typically airgapped kubernetes environments will have pipelines for processing images, and secured container registries.  This is example will cover the basic approach, namely:
- Downloading the container images
- Pushing them to a local registry
- Installing chart, using values pointing to the local registry

Ensure you have completed the [pre-requisites](../prereqs/README.md) before proceeding.

### Setting up the local registry

Download an airgap bundle as per the [instructions here](../common/README.md#download-airgap-bundle)

Upload the images in the downloaded bundle.  In this example we'll use the [kots cli](https://docs.replicated.com/reference/kots-cli-getting-started) - which will do it directly from the bundle all in one step.
> Note registry-localhost was set up as a loopback host entry in the [prerequisites](../prereqs/README.md) - it should resolve to the registry setup by k3d when the cluster was created.  This is a example only, and in this dev case, the credentials are required by the cli, but ultimately ignored.

```
kubectl kots admin-console push-images ~/2024.1.0.airgap registry-localhost:5000 --registry-username reguser --registry-password pw --namespace howso --skip-registry-check
```

You can check the images in the local registry with the following command:
```
curl -s http://registry-localhost:5000/v2/_catalog | jq .
```

### Create datastore secrets 
See the explanation in [basic installation](../basic/README.md#create-datastore-secrets) for more details.

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

### Pull component charts

This steps shows how you can pull the charts on a machine with internet access, and then copy them to the airgapped environment.

Note the use of untar is just so you don't need to know the version, for the next step (the tarball is named with the version).  

```
tmp_dir=$(mktemp -d) # Create a temporary directory to store the charts
cd $tmp_dir
helm pull oci://registry.how.so/howso-platform/stable/minio --untar --untardir .
helm pull oci://registry.how.so/howso-platform/stable/nats --untar --untardir .
helm pull oci://registry.how.so/howso-platform/stable/postgresql --untar --untardir .
helm pull oci://registry.how.so/howso-platform/stable/redis --untar --untardir .
helm pull oci://registry.how.so/howso-platform/stable/howso-platform --untar --untardir .
cd -
tar -czvf howso-platform-charts.tar.gz $tmp_dir -C $tmp_dir . # Create a tarball of the charts
```


### Install component charts 

The tarball can be copied to the airgapped environment, and then extracted and installed.  In this case we're using the same machine - the commands are the same, if a suitable `tmp_dir` is set.


Minio
```
helm install platform-minio $tmp_dir/minio --namespace howso --values helm-airgap/manifests/minio.yaml --wait
```

NATS
```
helm install platform-nats $tmp_dir/nats --namespace howso --values helm-airgap/manifests/nats.yaml --wait
```

Postgres
```
helm install platform-postgres $tmp_dir/postgresql --namespace howso --values helm-airgap/manifests/postgres.yaml --wait
```

Redis
```
helm install platform-redis $tmp_dir/redis --namespace howso --values helm-airgap/manifests/redis.yaml --wait
```

Howso Platform (install last - when all other components are ready).  Time to install will vary depending on network and resources.  
```
helm install howso-platform $tmp_dir/howso-platform --namespace howso --values helm-airgap/manifests/howso-platform.yaml
```

Check the status of the pods in the howso namespace, as they come online (CTRL-C to exit).
```
watch kubectl -n howso get po 
```

Setup a test user and environment using the [instructions here](../common/README.md#create-test-environment)

