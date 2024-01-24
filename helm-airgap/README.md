# Helm Airgap Installation for Howso Platform

## Introduction

This guide details the process of deploying the Howso Platform using Helm in a airgapped Kubernetes environment.  The main goal is not use external registries for both container images, and Helm charts.  Instead additional steps are added to download/upload these components. The chart values are also modified to use the local registry.

A real airgapped kubernetes environments will have pipelines for [scanning images](../container-scanning/README.md), and their own secured container registries.  This example will use a local registry setup by k3d.

Ensure you have completed the [pre-requisites](../prereqs/README.md) before proceeding, and have a kubernetes cluster running, with a howso namespace, the kubectl kots plugin installed, and are logged into the Helm registry.

### Download container images

Download an airgap bundle as per the [instructions here](../common/README.md#download-airgap-bundle).

### Download Helm charts

This steps shows how you can pull the charts on a machine with internet access, and then copy them to the airgapped environment.

Note the use of untar is just so you don't need to know the version, for the next step (the tarball is named with the version).  

```bash
tmp_dir=$(mktemp -d) # Create a temporary directory to store the charts
cd $tmp_dir
# Pull the charts from the Helm registry into the temporary directory
helm pull oci://registry.how.so/howso-platform/stable/minio --untar --untardir .
helm pull oci://registry.how.so/howso-platform/stable/nats --untar --untardir .
helm pull oci://registry.how.so/howso-platform/stable/postgresql --untar --untardir .
helm pull oci://registry.how.so/howso-platform/stable/redis --untar --untardir .
helm pull oci://registry.how.so/howso-platform/stable/howso-platform --untar --untardir .
cd -
# Create a tarball of the charts in the temporary directory
tar -czvf howso-platform-charts.tar.gz -C $tmp_dir . # Create a tarball of the charts
echo "Charts are in $tmp_dir/howso-platform-charts.tar.gz"
```

### Upload images to container registry 

In this example we'll use the [kots cli](https://docs.replicated.com/reference/kots-cli-getting-started) - which can upload images directly from the airgap bundle in one step (other methods are possible).
> Note registry-localhost was set up as a loopback host entry in the [prerequisites](../prereqs/README.md) - it should resolve to the registry container setup by k3d when the cluster was created. 
It is assumed that the downloaded airgap bundle has been moved to the airgapped environment - and is available at the path `~/2024.1.0.airgap`.

#### Check connectivity to the local registry

```sh
curl -s http://registry-localhost:5000/v2/_catalog | jq .
```
> If the above command fails - troubleshoot your container engine setup, and ensure k3d was installed correctly. 

#### Push the images to the local registry

> With this dev setup, the registry credentials, though required by the cli, are ultimately ignored.
```
kubectl kots admin-console push-images ~/2024.1.0.airgap registry-localhost:5000 --registry-username reguser --registry-password pw --namespace howso --skip-registry-check
```

You can check the images in the local registry with the command from the earlier [step](#check-connectivity-to-the-local-registry).

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


### Helm values files

The values files for the charts need to be modified to use the local registry.  The manifests directory contains the modified values files for each chart.  You can compare the differences with the non-airgap versions with the following command:- 

```sh
diff helm-basic/manifests/ helm-airgap/manifests/ --color
```
> Note the Howso Platform chart has a global image setting, which is used for all images in the chart.  The other charts approaches may vary.  This example, with basic datastore installations, may not change all possible image references.

### Install Helm charts 

The chart [tarball](#download-helm-charts) can be copied to the airgapped environment, and then extracted and installed.
> In this case we're using the same machine, if not, make sure a _tmp_dir_ variable is set to the directory where the charts are extracted.


Minio
```sh
helm install platform-minio $tmp_dir/minio --namespace howso --values helm-airgap/manifests/minio.yaml --wait
```

NATS
```sh
helm install platform-nats $tmp_dir/nats --namespace howso --values helm-airgap/manifests/nats.yaml --wait
```

Postgres
```sh
helm install platform-postgres $tmp_dir/postgresql --namespace howso --values helm-airgap/manifests/postgres.yaml --wait
```

Redis
```sh
helm install platform-redis $tmp_dir/redis --namespace howso --values helm-airgap/manifests/redis.yaml --wait
```

Howso Platform (install last - when all other components are ready).
```sh
helm install howso-platform $tmp_dir/howso-platform --namespace howso --values helm-airgap/manifests/howso-platform.yaml
```

> **Note** You can remove installed charts with `helm uninstall` i.e. `helm uninstall platform-redis --namespace howso`.  Check each chart seems to be running correctly before installing the next. 

Check the status of the pods in the howso namespace, as they come online (CTRL-C to exit).
```
watch kubectl -n howso get po 
```

If there are any issues, check the logs of the pods, and the [troubleshooting](../common/README.md#troubleshooting) section.

Setup a test user and environment using the [instructions here](../common/README.md#create-test-environment)

