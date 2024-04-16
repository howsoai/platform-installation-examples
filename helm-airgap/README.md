# Helm Air-gap Installation for Howso Platform

## Introduction

This guide details the process of deploying the Howso Platform using Helm in an air-gapped Kubernetes environment.  The main goal is to avoid public internet registries for both container images and Helm charts; allowing the Kubernetes environment to have restricted network access.  As such additional steps are required to download/upload these components and the chart values are modified to use the local registry.

Production air-gapped Kubernetes environments will likely have pipelines for [scanning images](../container-scanning/README.md) and secured container registries.  This illustrative example will use the unsecured local registry setup by k3d.

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding.

### Prerequisites TLDR

Not your first run-through?  Apply the following to get up and running quickly. 
```sh
# install kots CLI https://kots.io/kots-cli/ 
# add local.howso.com pypi|api|www|management.local.howso.com and registry-localhost to /etc/hosts 
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

## Steps

### Download container images

Download an air-gap bundle as per the [instructions here](../container-images/README.md#download-air-gap-bundle).

> Note the air-gap bundle is a tarball of the images, but also includes the manifests and scripts for a [kots install](../kots-existing-cluster-airgap/README.md) - those additional artifacts are not used in helm installations - the bundle is simply used to get the images into the air-gapped environment.


### Download Helm charts

This step shows how you can pull the charts on a machine with internet access, and then copy them to the air-gapped environment.

> Note: The use of `--untar` is just so you don't need to know the version for the next step (the actual tarball will be named with the version).  

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

### Upload images to the container registry 

In this example, we'll use the [kots cli](https://kots.io/kots-cli/) - which can upload the images directly from the air-gap bundle to the k3d local registry in one step (other methods are possible).  It can also drive [Kots](../kots-existing-cluster/README.md) installations, but we're not using that feature here.

> Note: registry-localhost was set up as a loopback host entry in the [prerequisites](../prereqs/README.md) - it should resolve to the registry container setup by k3d when the cluster was created. 

This example will assume that the downloaded air-gap bundle has been moved to the air-gapped environment - and is available at the path `~/2024.4.0.airgap`.  Adjust the path as necessary.

#### Check connectivity to the local registry

```sh
curl -s http://registry-localhost:5000/v2/_catalog | jq .
```
> If the above command fails (an empty json response object is expected) - troubleshoot your container engine setup, and ensure k3d was installed correctly. 

#### Push the images to the local registry

> Note: With this dev setup, the registry credentials, though required by the cli, are ultimately ignored.

```sh
kubectl kots admin-console push-images ~/2024.4.0.airgap registry-localhost:5000 --registry-username reguser --registry-password pw --namespace howso --skip-registry-check
```

You can check the images are in the local registry with the command from the earlier [step](#check-connectivity-to-the-local-registry).

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

The values files for the charts need to be modified to use the local registry.  The manifests directory contains the modified values files for each chart.  You can compare the differences with the non-air-gap versions with the following command:- 

```sh
diff helm-basic/manifests/ helm-airgap/manifests/ --color
```
> Note the Howso Platform chart has a global image setting, which is used for all images in the chart.  The other charts approaches may vary.  This example, with basic datastore installations, may not change all possible image references.

### Install Helm charts 

The chart [tarball](#download-helm-charts) can be copied to the air-gapped environment, and then extracted and installed.
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

Howso Platform
```sh
helm install howso-platform $tmp_dir/howso-platform --namespace howso --values helm-airgap/manifests/howso-platform.yaml
```

> **Note** You can remove installed charts with `helm uninstall` i.e. `helm uninstall platform-redis --namespace howso`.  Check each chart seems to be running correctly before installing the next. 

Check the status of the pods in the howso namespace, as they come online (CTRL-C to exit).
```
watch kubectl -n howso get po 
```

If there are any issues, check the logs of the pods, and the [troubleshooting](../common/README.md#troubleshooting) section.

Set up a test user and environment using the [instructions here](../common/README.md#login-to-the-howso-platform).

Confirm that the images are all pulled from the internal registry, and not the external registry.
```sh
kubectl -n howso get po  -oyaml  | grep 'image:'
```