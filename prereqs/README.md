# Howso Platform Setup Examples Prerequisites

Prerequisites for the Howso Platform installation examples.

## Resources

To run the examples well requires a workstation with at least 32GB of RAM and 8 CPU cores.  If you are low on resources, shut down any other applications you can, and try the single node k3d cluster.

## Workstation OS

These examples use local workstation installs to inform production Howso Platform installations.  Production installations are expected to be amd64 on a supported Linux distribution.  These local examples should work on Windows, Mac (x86 or arm64), or Linux (x86 or arm64) should work. 

> Note the air-gap examples use image archives that only contain amd64 images.  Mac Silicon amd64 emulation (rosetta) will work enough that the environment will start, but it is not able to complete machine learning tasks. 

## Container Runtime

Docker for Windows/Mac or equivilent.  On mac increase the memory and cpu limits.

## Tools

Install the following:-

- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes command line tool, if not installed with container runtime 
- [k3d](https://k3d.io/) - k3s in docker
- [helm](https://helm.sh/) - Kubernetes package manager
- [kots plugin](https://kots.io/kots-cli/) - kubectl kots cli plugin _for uploading images in air-gap bundles_
- [argocd cli](https://argo-cd.readthedocs.io/en/stable/cli_installation/) - argocd cli _for argocd install examples_


For Openshift examples, you'll need to install the following:-

- [OpenShift Local (CodeReady Containers)](https://developers.redhat.com/products/openshift-local/getting-started) - OpenShift local development environment 


## Accessing the Howso Platform Helm Registry

Access to the Helm registry for the Howso Platform requires a Howso Platform license.  Log in with your email, registered with the customer portal, and your license ID as the credential.

You can find your license ID in two ways: either from the address bar on the downloads page or within your license file, where it's listed under the `license_id:` field.

The charts are stored in an OCI (Open Container Initiative) type registry, and you'll log in using the email registered with the customer portal and your license ID. Use the following command to log in, replacing `your_email@example.com` with your registered email and `your_license_id` with your actual license ID:


```bash
helm registry login registry.how.so --username your_email@example.com --password your_license_id
```

> Note. Only licenses for the Howso Platform Kots application (howso-platform vs legacy diveplane-platform licenses) will work with the Howso Platform Helm charts.  If you have a legacy license, contact your Howso representative to get a new one.


## Local Kubernetes Cluster Setup 

### Simple Single Node K3D Cluster

```
k3d cluster create --config prereqs/k3d-single-node.yaml
```

Confirm kubectl access, and check the cluster is running.
> This command waits for the metrics server to be ready - a good indicator the cluster is fully up.
```
kubectl -n kube-system wait --for=condition=ready --timeout=180s pod -l k8s-app=metrics-server
```


### Multi Node K3D Cluster

The Howso Platform is a resource-intensive machine learning platform. It dynamically creates new kubernetes workloads through an operator; these can require considerable CPU and memory resources. 

For optimal performance installations should:- 
- Allow for a substantial number of available nodes, ideally within an autoscaling infrastructure. 
- Dedicate nodes to either the core services or the dynamic worker pods. 

Such setups ensure that the platform can scale resources efficiently as workloads increase.

> Note - the typical autoscaling pattern is:- to use taints/tolerations to control the scheduling of worker pods onto specific node groups; allow the worker node group to autoscale. When the Howso Platform operator creates new workloads it will schedule them onto the worker node group and the kubernetes autoscaler will add new nodes to accomodate.

Though these examples are for local installations - mimicking a larger cluster demonstrate's how labels and taints can be used to control scheduling of pods across multiple nodes.

```
k3d cluster create --config prereqs/k3d-multi-node.yaml
```

Check/wait for the cluster to be ready.
```
kubectl -n kube-system wait --for=condition=ready --timeout=180s pod -l k8s-app=metrics-server
```

Label the server node - to keep worker pods off it
```
kubectl label nodes k3d-platformk8s-server-0 howso.com/allowWorkers=False --overwrite
```

For each agent node, apply a taint so only worker pods are scheduled.
```
kubectl taint nodes k3d-platformk8s-agent-{0,1,2} howso.com/nodetype=worker:NoSchedule --overwrite
```

## Create a howso namespace
```
kubectl create namespace howso
```

## Setup Hosts
The Howso Platform uses a number of subdomains under a parent domain.  For a local set-up, you can use the following entries in your hosts file.
```
127.0.0.1 local.howso.com
127.0.0.1 pypi.local.howso.com
127.0.0.1 api.local.howso.com
127.0.0.1 www.local.howso.com
127.0.0.1 management.local.howso.com
127.0.0.1 registry-localhost # For air-gap install example
127.0.0.1 argocd.local.howso.com # For Argo CD install example
```

## Uninstalling the Howso Platform

### Remove K3d Cluster
```
k3d cluster delete platformk8s
```
