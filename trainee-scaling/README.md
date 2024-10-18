# Trainee Scaling

## Overview

The Howso Platform can automatically change the resource requirements of a trainee.  This can help workloads where the application is unclear on the specific resource requirements of the workload, or if small trainees are frequently created.

## Prerequisites

- [General prerequisites](../prereqs/README.md)
- [Helm Online Installation for Howso Platform](../helm-basic/README.md)

## Enabling Autoscaling

A number of autoscaling settings are included in the Helm chart configuration.  A [sample configuration](manifests/howso-platform.yaml) enables one potential configuration.  This can be added to an existing installation with a Helm command such as

```sh
helm upgrade --install howso-platform \
  oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values helm-basic/manifests/howso-platform.yaml \
  --wait \
  --values trainee-scaling/manifests/howso-platform.yaml  # <-- add to basic setup
```

## Configuration Options

By default all scaling options are disabled.  There are two separate options that need to be enabled for autoscaling to work:

```yaml
scaling:
  enabled: true
  autoscaling:
    enabled: true
```

If `autoscaling` is not enabled then the `defaultSize` will be used to set trainee resources for trainees that do not explicitly request resources in client code, but no other autoscaling functionality is used.

### Named Sizes

The configuration contains a catalog of named sizes.  The default size can be specifically configured

```yaml
scaling:
  resources:
    trainees:
      defaultSize: small
      # sizes: [...]
```

A list of sizes is also in the configuration.  This is an ordered list.  Whenever the Platform scales a trainee up to a larger size, it uses the next size in this list, and similarly scaling down uses the previous size.  If custom configuration provides `sizes:`, it must provide the complete list of sizes that are available to use.

Each item in the list specifies the Amalgam library type and Kubernetes resource constraints.  For example,

```yaml
scaling:
  resources:
    trainees:
      sizes:
        - name: small
          processType: multithreaded # or singlethreaded
          requests:
            memory: 1Gi
            cpu: '2'
          limits:
            memory: 1Gi
            cpu: '4'
```

The sizes in the default configuration are:

| Size      | Process type   | Req. Memory | Req. CPU | Lim. Memory | Lim. CPU |
|-----------|----------------|-------------|----------|-------------|----------|
| xxx-small | singlethreaded | 128Mi       | 0.25     | 128Mi       | 1000m    |
| xx-small  | singlethreaded | 256Mi       | 0.50     | 256Mi       | 1000m    |
| x-small   | singlethreaded | 512Mi       | 1        | 512Mi       | 1        |
| small     | multithreaded  | 1Gi         | 2        | 1Gi         | 4        |
| medium    | multithreaded  | 2Gi         | 4        | 2Gi         | 8        |
| x-large   | multithreaded  | 8Gi         | 6        | 8Gi         | 12       |
| xx-large  | multithreaded  | 12Gi        | 8        | 12Gi        | 16       |

An administrator with access to the Kubernetes cluster can run

```sh
kubectl get trainee -n howso
```

to see the current size and resource utilization of each trainee.

### Scaling Events

The Howso Platform can scale trainees in response to out-of-memory events, memory utilization, and CPU utilization.

If a trainee Pod is terminated because it has run out of memory, the Platform can scale it up if requested.  This setting is on by default if autoscaling in general is enabled.

```yaml
scaling:
  resources:
    trainees:
      scalingEvents:
        outOfMemory:
          enabled: true  # on by default
```

The Platform can also scale trainees based on observed memory utilization.  This is the memory utilization reported by the cluster, for example in `kubectl top pod`, and includes both memory used by the Howso Engine itself and also the worker process around it.  The Platform can scale either up or down.  In both cases the thresholds are specified as percentages of the current size's memory requests.  If the `scaleDownThreshold` is 0 then the trainee will never be scaled down; similarly, `scaleUpThreshold` can be set high enough that it is never reached without the Pod reaching its memory limit.

```yaml
scaling:
  resources:
    trainees:
      scalingEvents:
        memory:
          enabled: true  # off by default
          scaleUpThreshold: 80  # percent of requested memory, default value
          scaleDownThreshold: 0  # percent of requested memory, default value
```

CPU-based autoscaling can be specified in the same way, under a `cpu:` configuration key.  Enabling this is not generally recommended due to the high variability in CPU utilization.

The Platform remembers the last time it has scaled any given trainee.  Out-of-memory scaling happens whenever a Pod is unexpectedly terminated from an out-of-memory event, but the other scaling events can only happen once in a configurable interval, by default 2 minutes.

```yaml
scaling:
  resources:
    trainees:
      scalingEvents:
        stabilizationWindowSeconds: 120
```

OOM and memory scale-up events happen immediately, terminating their Pods and possibly causing in-progress work to be restarted.  Other scaling events do not happen until the worker reports it is idle.

### Interactions With Replicas

If a client requests multiple replicas of a trainee, there will be multiple Pods running workers.  One of these Pods is the primary replica.  Only this Pod is monitored for out-of-memory events and resource utilization.  The other replicas are managed normally by Kubernetes, but if a read replica is terminated due to an out-of-memory event, it will not cause itself or any other trainee to scale up.

All replicas have the same resource settings.  If the Platform scales a trainee's resources, all replicas are recreated at the new resource size.

Scale-down actions and other configuration changes only happen if a trainee's primary replica is idle.  If there are multiple replicas, it is possible that other replicas can have long-running jobs in flight while the primary replica reports idle.  These jobs will be restarted in this case.

### Caveats

The default settings shown above use the same values for memory requests and limits.  Kubernetes schedules Pods on nodes based only on requests.  If limits are greater than requests, then it is possible for a node to run out of physical memory, even if every individual Pod is within its limits; in this case a Pod could be killed off if it is above its requests.  The out-of-memory detection in the Platform notices this case but does not treat it differently from other out-of-memory events, and it will increase the trainee size.  This could actually result in increased memory pressure on the cluster, though higher resource requests will make it less likely that a worker Pod will be unexpectedly terminated.

The cluster must contain nodes with at least enough free capacity to handle the resource requests in the size list.  The operating system and Kubernetes itself have some overhead.  If the cluster consists of nodes with 8 GiB of physical memory, and the Platform scales a trainee up to the `x-large` size shown above with an 8 GiB memory request, it will not fit anywhere in the cluster, and the trainee will be non-operational.
