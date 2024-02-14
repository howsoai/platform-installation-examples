# Compliance Benchmarks

## Introduction
https://www.cisecurity.org/benchmark/kubernetes

CIS Publish security guidelines for Kubernetes.  Installed On Prem via helm charts - most of the items apply to the customer's Kubernetes cluster.  Though many of the items are applicable.  The following information is intended to help administrators and security resources tasked with ensuring their Kubernetes cluster running Howso Platform meets the CIS benchmarks standards.

## Howso's Approach
Howso Platform, installed via Helm charts, intends to provide configuration options that allow customers to meet CIS benchmarks.  Where appropriate Howso Platform will choose defaults that represent secure best practices. Doing so has to balance with other trade-offs for the default configuration.  These other considerations include :- 

- Is meeting the benchmark best dealt with at the Kubernetes framework layer.
> For example - encrypted communication controlled by identity, between all components, is best tackled with components such as service mesh. Howso Platform communications can all be configured individually to use TLS - but for in-cluster communication is not a recommended approach. 

- Does meeting the benchmark with default configuration require complicating the installation of dependent components.
> Enabling initial installs of the Howso Platform to be straight-foward is also a prority.  Since Howso Platform relies on a number of datastores, that must be provided - it is a deliberate choice to hone defaults to work with select, production level, charts in their default, or near default configurations.  It is expected that customers alter their chart configurations to meet their own security requirements - and adjust the Howso Platform configuration to match. 

- Not all Kubernetes distributions work well with some configuration.
> Openshift will object to run ids that are not in the range of the security context constraints, but certain security benchmarks will 

This documentation will 

## Run the CIS Benchmarks
Use the [basic helm install guide](../helm-basic/README.md) to install Howso Platform, and ensure it is running correctly.

```sh
# pre-requisites TLDR
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
# Install the [linkerd cli](https://linkerd.io/2/getting-started/) and the certificate tool [step](https://smallstep.com/docs/step-cli/).
# Setup the Kubernetes cluster
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl -n kube-system wait --for=condition=ready --timeout=180s pod -l k8s-app=metrics-server
kubectl create namespace howso
# Create datastore secrets 
kubectl create secret generic platform-minio --from-literal=rootPassword="$(openssl rand -base64 20)" --from-literal=rootUser="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
kubectl create secret generic platform-postgres-postgresql --from-literal=postgres-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
kubectl create secret generic platform-redis --from-literal=redis-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
# Install component charts 
helm install platform-minio oci://registry.how.so/howso-platform/stable/minio --namespace howso --values helm-basic/manifests/minio.yaml --wait
helm install platform-nats oci://registry.how.so/howso-platform/stable/nats --namespace howso --values helm-basic/manifests/nats.yaml --wait
helm install platform-postgres oci://registry.how.so/howso-platform/stable/postgresql --namespace howso --values helm-basic/manifests/postgres.yaml --wait
helm install platform-redis oci://registry.how.so/howso-platform/stable/redis --namespace howso --values helm-basic/manifests/redis.yaml --wait
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values helm-basic/manifests/howso-platform.yaml --wait --timeout 20m
```

## CIS Benchmarks

https://github.com/aquasecurity/kube-bench

```sh
kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
```

The results are availble in the logs of the kube-bench job pod.
```sh
kube_bench_pod=$(kubectl get po -l batch.kubernetes.io/job-name=kube-bench -oname)
kubectl logs $kube_bench_pod
```

```sh
kubectl apply -f cis-benchmarks/manifests/kube-bench-job.yaml
```


## Trivy

https://github.com/aquasecurity/trivy


```sh
trivy k8s --namespace howso --report summary all
```

```sh
trivy k8s -n howso --components workload  --report summary --compliance k8s-cis all | grep FAIL
```