# Securing Howso Platform 

## Examples
[prerequisites](../prereqs/README.md)
---
[Linkerd and Network Policies](linkerd/README.md)
[Container Scanning](container-scanning/README.md)


## Introduction

Howso Platform installed on-prem via Helm charts requires a number of security considerations.  Firstly - it is necessarilly a shared security model - between the Howso Platform application, and the operators of the Kubernetes cluster.

Kubernetes is a highly customizable platform, and many aspects that come under application security (i.e. establishing TLS between components) by best practice are bes best done at the framework level, using components such as a service mesh.  As such Howso Platform, when distributed as a Helm chart, can not independently claim to be secure by default - it is the wrong layer for that requirement.  It is designed to easilly fit into a secure environment - this section will cover the main topics to consider.


## Encrypted Communication 

Howso Platform consists of a number of services and datastores, and a message queue (NATS).  Communication between these components may be considered to be within a trusted network, and only external communication needing to be encrypted.  Alternatively these docs will cover 2 approaches:

- Manually configuring TLS to NATS and external datastores.
- Using a service mesh to automatically provide mTLS between all components 

Manually configuring TLS between all components is possible - and is how the KOTS configuration of the the Howso Platform is provided.  It is a significantly more complex set-up.  Since Howso Platform consists of seperately installed (or otherwise provided) datastores, it necessarilly can't all work out of the box. Secure communications require secret management and Public Key Infrastructure (PKI) tooling that works with Kubernetes.

Customers looking to install into an existing Kubernetes, where secure communication between the internal components is required it is recommended to use a service mesh. If your enterprise does not use a service mesh, but also insists that running containers that are part of the same application use mTLS, it is worth analysing the requirement and the pre-condition, before deciding to manually configure all the TLS. 



### Manually Configuring TLS

> Note as stated - this documentation is for advanced use cases - or for showing how to securely configure external datastores (i.e. a managed cloud postgres).  It is unlikely to be the best solution for customers with existing Kubernetes operations.

Configuration is required both in the Howso Platform Chart, and the datastore/NATS charts in order to establish secure communication.  This configuration will involved Kubernetes Public Key Infrastructure (PKI) tools to do efficiently.  It will be required to create  


#### Cert Manager

Cert Manager is a Kubernetes add-on that automates the management and issuance of TLS certificates from various issuing sources





### Service Mesh
Alternatively - Service mesh can be installed to `automatically` provide mTLS between all communicating end points.  Typically a larger Kubernetes installation will 



identity.


## Encrypted Storage
framework level 

## Security Scanning
Howso internally scans our container images for vulnerabilities.  Internally we use Artifactory x-Ray across the components of our stack.  Our customers use their own scanning tools, and we  




## Networking

### Network Policies

### Service Mesh 

- reporting CVES (support@howso.com)
- airgap
- container scanning
- RBAC
- Secrets Management - external secrets operator
- Pod security scanning 
- datree
## Custom Ingress Certs
[Custom Ingress](custom-ingress/README.md)


## App security 

#### oidc

#### oidc sso
AD

platform-admin bootstrapping