# Howso Platform Setup Examples Prerequisites
To run the examples in a local workstation, you'll need to meet the following requirements: 

## Resources
Expect to need a workstation with at least 32GB of RAM and 8 CPU cores to run the examples.

## Container Runtime
Docker for Windows/Mac or equivilent.  On mac increase the memory and cpu limits.

## Tools

Install the following:-

- [kubectl](https://kubernetes.io/docs/tasks/tools/) - kubernetes command line tool, if not installed with container runtime 
- [k3d](https://k3d.io/) - k3s in docker
- [helm](https://helm.sh/) - kubernetes package manager


For Openshift examples, you'll need to install the following:-

- [CodeReady Containers](https://developers.redhat.com/products/codeready-containers/overview) - OpenShift local development environment 


## Local Kubernetes Cluster Setup 

### Simple Single Node Cluster


```
k3d cluster create --config prereqs/k3d-single-node.yml
```

Confirm kubectl access, and check the cluster is running
```
kubectl -n kube-system wait --for=condition=ready --timeout=180s pod -l k8s-app=metrics-server
```

### Multi Node Cluster

```
k3d cluster create --config prereqs/k3d-multi-node.yml
```

Confirm kubectl access, and check the cluster is running
```
kubectl -n kube-system wait --for=condition=ready --timeout=180s pod -l k8s-app=metrics-server
```

Label the server node - to keep worker pods off it

```
kubectl label nodes k3d-platformk8s-server-0 howso.com/allowWorkers=False --overwrite
```

> For each agent node, apply a taint so only worker pods are scheduled there

```
kubectl taint nodes k3d-platformk8s-agent-0 howso.com/nodetype=worker:NoSchedule --overwrite
kubectl taint nodes k3d-platformk8s-agent-1 howso.com/nodetype=worker:NoSchedule --overwrite
kubectl taint nodes k3d-platformk8s-agent-2 howso.com/nodetype=worker:NoSchedule --overwrite
```