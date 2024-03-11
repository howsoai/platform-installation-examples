# Securing Howso Platform 

## Examples

- [Prerequisites](../prereqs/README.md)
---
- [Linkerd and Network Policies](linkerd/README.md)
- [Container Scanning](container-scanning/README.md)


## Introduction

Howso Platform installed on-prem via Helm charts requires several security considerations. Firstly, it is necessarily a shared security model between the Howso Platform application and the operators of the Kubernetes cluster.

Kubernetes is a highly customizable platform, and many aspects that are part of the application security (i.e., establishing TLS between components) are best done at the framework level, using components such as a service mesh. As such, Howso Platform, when distributed as a Helm chart, cannot independently claim to be secure by default – it is the wrong layer for that requirement. It is however designed to fit into a secure environment, and this section will cover the main topics to consider.


## Encrypted Communication

Howso Platform consists of several services, data stores, and a message queue (NATS). The basic installation examples in this documentation do not encrypt this traffic.  In the case where communication between these components is considered to be within a trusted network, this may be acceptable. 
However, in many cases, it is necessary to establish encrypted communication between these components. 

These docs will cover two approaches:

- Using a service mesh to automatically provide mTLS between all components
- Manually configuring TLS to NATS and external data stores

> Note: In a Kubernetes cluster, depending on the Container Network Interface (CNI) used, traffic between nodes may be encrypted. Overlay networks, such as Calico or Weave, can be configured to encrypt traffic between nodes. This is a separate concern from the application-level encryption discussed here, but may be a relevant consideration when assessing the security posture of the cluster and its applications. 


### Service Mesh

Service mesh can be installed to automatically provide mTLS between all communicating endpoints. Typically, customers with larger Kubernetes teams will likely have a service mesh that they use.

With multiple data stores and a message queue, the Howso Platform can be complex to secure. A service mesh provides a single, uniform way to secure communication between all components, alongside other benefits such as observability and traffic control.  It is therefore the recommended approach for securing communication between the Howso Platform components.

See the [Linkerd and Network Policies](../linkerd/README.md) section for an example of using a service mesh with the Howso Platform.

### Manually configuring TLS between components

It is possible to manually configure TLS between the Howso Platform and its data stores and message queue. 

Within the Howso Platform values file, under the `datastores` and `nats` sections, is the configuration for setting up TLS connections.  To configure TLS communication to external data stores (i.e. an AWS RDS Postgres, or S3) override the values in this section.

If configuring TLS to the data stores and message queue charts, then the corresponding configuration will be required in the NATS, minio, Redis, and Postgres chart installations.

> Though possible, setting up TLS manually between Howso Platform and all backend charts is considered an advanced use-case.  To do this efficiently will involve setting up Kubernetes Public Key Infrastructure (PKI) tools i.e. cert-manager; alongside significant configuration of the Howso Platform and backend charts.  It is recommended to use a service mesh for this purpose.  Reach out to Howso Support for further guidance. 



## Encrypted Storage

Howso Platform itself does not directly use Persistent Volumes, though the minio, Postgres, Redis (optionally), and NATS chart configurations will create Persistent Volume Claims (PVCs).  In the documented examples, these PVCs will use the default storage class of the Kubernetes cluster, though they can be configured to use a specific storage class. 

Using a Storage Class that meets your security requirements is considered to be on the Kubernetes operator's side of the shared security model. 


## Security Scanning 

See the [Container Scanning](../container-images/README.md#howsos-approach) section for information on scanning the Howso Platform container images, and Howso Platform's approach to container security.



## Networking

### Network Policies

Network policies can be used to control traffic between pods and limit access to the Howso Platform components.

TODO - 

If using a service mesh, the logic of which podSelectors to use changes, more information can be found in the [Linkerd and Network Policies](linkerd/README.md) section.


## Custom Ingress Certs

Custom ingress certificates can be used to secure external access to the Howso Platform. More information on configuring custom ingress certificates can be found in the [Custom Ingress](custom-ingress/README.md) section.
