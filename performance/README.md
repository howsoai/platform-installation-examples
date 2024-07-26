# Howso Platform Performance

## Overview

This guide covers performance considerations for the Howso Platform and client installation. 

## TLDR
Use a dedicated Kubernetes cluster for Howso Platform.  Increase the size of NATS, Redis, Postgres.  Use cluster autoscaling.  Run workloads from a large dedicated client machine.

## Cluster Configuration

### Dedicated Cluster

When run in Howso Platform trainees are created as new (stateful set) pods on demand.  
- Individual trainees can be very large - it is not uncommon to dedicate 10s or cpu resources, and even more Gb of memory.  
- The Kubernetes API server is used to create and manage these pods.  The API server is a critical component of the cluster, can come under load, and be a bottleneck.

As such, the profile of the cluster can be demanding and very dynamic.  Therefore it is recommended to run the Howso Platform on a dedicated cluster, for the best performance (for the Howso Platform and other workloads).


### Dependent Charts

As discussed extensively elsewhere in this guide, Howso Platform relies on several dependent charts.  NATS, Redis, Postgres, Minio.  These charts can be tuned independently of the Howso Platform chart.  The included [manifests](./manifests) provide the basics for tuning these charts.

The out of the box installations of these charts, particularly NATS, Redis and Postgres are small installations.  Even these should run reasonably well for basic examples, but for demanding workloads, simply increasing the resources allocated to their primary workloads is very beneficial. 

In rough order of impact:

#### NATS

NATS is used for inter-service communication.  The [NATS manifest](./manifests/nats.yaml) provides a configuration that runs a cluster of 3 JetStream enabled NATS servers - with increased resources.  Check out the [NATS Chart](https://github.com/nats-io/k8s/tree/main/helm/charts/nats) documentation for more information.

#### Redis

Redis is used for offloading large data messages from NATS and storing message responses from trainees.  Currently Howso Platform components all need to read & write to Redis, so there is no advantage in Read Replicas (without sentinel).  The [Redis manifest](./manifests/redis.yaml) provides a configuration that runs a single Redis server - with increased resources that should perform well for larger workloads.

#### Postgres

Postgres is used for storing the state of the Howso Platform.  The [Postgres manifest](./manifests/postgres.yaml) provides a configuration that increases the resources allocated to the Postgres server - so that it should not be a bottleneck for larger workloads.

#### Minio

The [Minio manifest](./manifests/minio.yaml) standalone mode chart installation has usually been sufficient for most workloads.  However, for larger workloads, the [Minio Chart](https://github.com/minio/minio/blob/master/helm/minio/README.md) can be extensively tuned or swapped out for a cloud s3 compatible service.

### Autoscaling / Node pools

Howso Platform is built to naturally take advantage of Kubernetes [Cluster Autoscaling](https://kubernetes.io/docs/concepts/cluster-administration/cluster-autoscaling/).  It is highly recommended to use this feature, to efficiently scale the cluster during a Howso Platform workload, and scale back down when the workload is complete.

Cluster Autoscaling setup is dependent on the cloud provider and/or the Kubernetes distribution. For example:
- AWS: The [Cluster Autoscaler](https://docs.aws.amazon.com/eks/latest/userguide/cluster-autoscaler.html) can be installed as a DaemonSet.
- GCP: The [Cluster Autoscaler](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler) can be enabled on the cluster.
- OpenShift: The [Cluster Autoscaler](https://docs.openshift.com/container-platform/latest/machine_management/applying-autoscaling.html) can be managed through the OpenShift web console or CLI.
- Azure AKS: The [Cluster Autoscaler](https://learn.microsoft.com/en-us/azure/aks/cluster-autoscaler) can be enabled directly from the Azure portal or via Azure CLI.

Cluster Autoscaling is conceptually simple.  When trainee pods are created, that do not fit in the existing cluster, the autoscaler will create new nodes to accommodate them.  When the trainee pods are deleted, the autoscaler will remove the nodes.

For the best performance, Howso Platform workloads should be split into two node pools.  One for the core services, NATS and datastores, and one for the trainee pods.  This allows the core services to run without interference from the trainee pods, and allows the trainee pods to be scaled independently of the core services.  The core node pool should be permenant and will not autoscale.  The trainee node pool should be autoscaling, allowing only trainee pods to run on it.

### Node Pool Configuration
When configuring optimal autoscaling configuration, it may be useful to refer to the [multi-node setup](../prereqs/README.md#multi-node-k3d-cluster) which demonstrates the use of taints and tolerations (in a local setup) to control pod scheduling across multiple nodes.

#### Core Services Nodes
The core services of Howso Platform and its dependent charts should run on 2 or 3 dedicated cluster nodes utilizing a [node label](../prereqs/README.md#multi-node-k3d-cluster), to keep trainee pods from starting on them.

```sh
kubectl label nodes k3d-platformk8s-server-0 howso.com/allowWorkers=False --overwrite
```

Note, some core services are set up to [auto-scale](#core-service-horizontal-pod-autoscaler).  The core services nodes can be set to to autoscale, to accomodate the increased load, as long as they maintain the minimum number of nodes required to run the core services. 

#### Trainee/Worker Pod Nodes
A node pool of worker nodes should be created; these nodes should be tainted with `howso.com/nodetype=worker:NoSchedule` allowing trainee pods to run on them.

The node pool should be configured with the cluster autoscaling to automatically add and remove nodes as needed.

The minimum number of nodes can be 0 for maximum efficiency, but it is worth considering a miniumum of 1 worker nodes, so that basic test workloads do not have to wait for a new node to be created.


#### Create wait time
By default, the Howso Platform client will wait 30 seconds for a trainee to be created, before erroring.  If the cluster is autoscaling (or slow), this is not enough time for a new node to come online, the worker image to be downloaded (this is done by the image-loader daemonset) and the trainee to start.

Increase the create wait time either via environment variable or in the client configuration (howso.yaml).  The value is in seconds, and 0 will wait indefinitely (though will be beholden to server timeouts).

```sh
export HOWSO_CLIENT_CREATE_MAX_WAIT_TIME=1200
```

```yaml
howso:
  ... 
  options:
    create_max_wait_time: 0
```

### Core service Horizontal Pod Autoscaler

Some of the core api services within Howso Platform use the [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) to scale the number of pods based on resource usage.  The built in configuration is likely to be sufficient for most workloads, but see the [manifests](./manifests/howso-platform.yaml) for the configuration or the [Helm Chart Values](../common/README.md#howso-platform-helm-chart-values) for more information.


## Client Configuration 


### Client Machine

Howso Platform workloads are typically driven by a client python application.  For large workloads, using multiple threads, i.e. using chunk scaling, the client machine is frequently a bottle neck.  Using developer workstations may be ok for small tasks or working on a script, but for large workloads - a permenant client machine close to the cluster is recommended. 

Create a dedicated client machine, with at least a core for every simultaneous trainee that the application will run.  Also note that non Howso Platform activity on the client, i.e. other miscellaneous data or machine learning tasks using python libraries, can further increase the demands on the client machine - especially when running simultaneous threads.

A stable network connection to the cluster is required.  A key reason that using, even a powerful developer workstations, can lead to issues is they frequently are using WiFi with VPNs, and may be expected to move - when a large run may expect to run for hours or days - this will result in issues. 


