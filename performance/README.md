# Howso Platform Performance Considerations

## Overview

This guide covers performance considerations for the Howso Platform and client installation. 

## TLDR
- Use a dedicated Kubernetes cluster for Howso Platform.
- Increase the size of NATS, Redis, Postgres.
- Use cluster autoscaling.
- Run workloads from a large dedicated client machine.

## Cluster Configuration

### Dedicated Cluster

In the Howso Platform, trainees (also known as workers) are created as new (stateful set) pods on demand.  
- Individual trainees can be very large - it is not uncommon to dedicate tens of cpu resources and even more Gb of memory to a single trainee.
- The Kubernetes API server is used to create and manage these pods.  The API server is a critical component of the cluster, can come under load, potentially impacting other cluster workloads. 

As such, the profile of the cluster can be demanding and very dynamic.  Therefore it is recommended to run the Howso Platform on a dedicated cluster for the best performance (for the Howso Platform and other workloads).


### Dependent Charts

As discussed extensively elsewhere in this guide, Howso Platform relies on several dependent charts.  NATS, Redis, Postgres, Minio.  These charts can be tuned independently of the Howso Platform chart.  The included [manifests](./manifests) provide some basic, but impactful tuning recommendations. 

The out of the box installations of these charts, particularly NATS, Redis and Postgres are small installations.  These should run reasonably well for basic local examples, but for demanding workloads, across large clusters, increasing the allocated resources is very beneficial. 

In rough order of impact:

#### NATS

NATS is used for inter-service communication.  This [NATS manifest](./manifests/nats.yaml) provides a configuration that runs a cluster of 3 JetStream enabled NATS servers - with increased resources.  Check out the [NATS Chart](https://github.com/nats-io/k8s/tree/main/helm/charts/nats) documentation for more information.

#### Redis

Redis is used for storing data messages and message responses.  Currently Howso Platform components need to both read and write to Redis, so there is no advantage in Read Replicas (without addionally adding sentinel).  The [Redis manifest](./manifests/redis.yaml) provides a configuration that runs a single Redis server - with increased resources that should perform well for larger workloads.

#### Postgres

Postgres is used for storing the state of the Howso Platform.  The [Postgres manifest](./manifests/postgres.yaml) provides a configuration that increases the resources allocated to the Postgres server - so that it should not be a bottleneck for larger workloads.

#### Minio

The [Minio manifest](./manifests/minio.yaml) standalone mode chart installation has usually been sufficient for most workloads.  However, for larger workloads, the [Minio Chart](https://github.com/minio/minio/blob/master/helm/minio/README.md) can be extensively tuned or swapped out for a cloud s3 compatible service.

### Cluster Autoscaling

Howso Platform is built to naturally take advantage of Kubernetes [Cluster Autoscaling](https://kubernetes.io/docs/concepts/cluster-administration/cluster-autoscaling/).  It is highly recommended to use this feature, to efficiently scale the cluster during a Howso Platform run, and scale back down when the workloads are complete.

Cluster Autoscaling setup is dependent on the cloud provider and/or the Kubernetes distribution. For example:
- AWS: The [Cluster Autoscaler](https://docs.aws.amazon.com/eks/latest/userguide/cluster-autoscaler.html) can be installed as a DaemonSet.
- GCP: The [Cluster Autoscaler](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler) can be enabled on the cluster.
- OpenShift: The [Cluster Autoscaler](https://docs.openshift.com/container-platform/latest/machine_management/applying-autoscaling.html) can be managed through the OpenShift web console or CLI.
- Azure AKS: The [Cluster Autoscaler](https://learn.microsoft.com/en-us/azure/aks/cluster-autoscaler) can be enabled directly from the Azure portal or via Azure CLI.

Cluster Autoscaling is conceptually simple; when trainee pods are created, that do not fit in the existing cluster, the autoscaler component will send messages to the infrastructure provider to create new nodes to accommodate them.  When the trainee pods are deleted, the autoscaler will remove the nodes.

For the best performance, Howso Platform workloads should be split into two node pools.  One for the core services, NATS and datastores, and one for the trainee pods.  This sets up the core services to run permently without interference from the trainee pods, and allows the trainee pods to be scaled independently of the core services.  The core node pool should have a permenant minimum number of nodes, optionally autoscaling (an extra node or 2) to allow for certain services to [scale](#core-service-horizontal-pod-autoscaler) under heavy load.  The trainee node pool should be autoscaling, potentially to a minimum of 0 nodes and up to the largest capacity required for the heaviest workloads.  Only trainee pods should run on the trainee node pool. 

#### Node Pool Configuration

When configuring autoscaling configuration, it may be useful to refer to the [multi-node setup](../prereqs/README.md#multi-node-k3d-cluster) which demonstrates the use of labels and taints (in a local setup) to control pod scheduling across multiple nodes.

##### Core Services Nodes

The core services of Howso Platform and its dependent charts should run on 2 or 3 dedicated cluster nodes utilizing a [node label](../prereqs/README.md#multi-node-k3d-cluster), to keep trainee pods from starting on them.

```sh
kubectl label nodes k3d-platformk8s-server-0 howso.com/allowWorkers=False --overwrite
```

Note, since some core services are set up to [auto-scale](#core-service-horizontal-pod-autoscaler) the core service nodes can be set to to autoscale to accomodate any increased demand under load.  They should not be allowed to scale below the minimum number of nodes required to run the core services.

##### Trainee/Worker Pod Nodes

A node pool of worker nodes should be created; these nodes should be tainted with `howso.com/nodetype=worker:NoSchedule` allowing trainee pods to run on them.

The worker node pool should be configured with cluster autoscaling to automatically add and remove nodes as needed.

The minimum number of nodes can be 0 for maximum efficiency, but it is worth considering a miniumum of 1 worker nodes so that basic test workloads do not have to wait for a new node to be created.


#### Create wait time

By default, the Howso Platform client will wait 30 seconds for a trainee to be created, before erroring.  If the cluster is autoscaling (or slow), this is not enough time for a new node to come online and the trainee pod to start.

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

Howso Platform workloads are typically driven by a client python application.  For large workloads, using multiple threads (i.e. chunk scaling), the client machine is frequently a bottle neck.  Using developer workstations may be ok for small tasks or working on scripts, but for large workloads a permenant client machine, close to the cluster, is recommended. 

Use a dedicated client machine, with at least a core for every simultaneous trainee that the client application is expected run.  Also note that non Howso Platform activity from the client application, i.e. other miscellaneous data or machine learning tasks, can significantly increase the demands on the client machine - especially when running simultaneous threads.

A stable network connection to the cluster is required.  A key reason that using even a powerful developer workstation can lead to issues is they frequently move, use WiFi and/or VPNs.  A large workload may expect to run for hours or days, network interuptions can lead to the client application losing connection to the cluster, and the run failing. 

