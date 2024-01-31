# Securing Howso Platform 

## Examples
[pre-requisites](../prereqs/README.md)
---
[Linkerd and Network Policies](linkerd/README.md)
[Container Scanning](container-scanning/README.md)


## App security 

oauth saml

platform-admin bootstrapping

## Introduction

Howso Platform installed on-prem via Helm charts requires a number of security considerations.  Firstly - it is necessarilly a shared security model - between the Howso Platform application, and the operators of the Kubernetes cluster.

Kubernetes is a highly customizable platform, and many aspects that come under application security (i.e. establishing TLS between components) by best practice are done at the framework level, using components such as service mesh.  As such Howso Platform, when distributed as a helm chart, can not independently claim to be secure by default - it is the wrong layer for that requirement.  It is designed to easilly fit into a secure environment - this section will cover the main topics to consider.


## mTLS

identity.


## Security Scanning
Howso internally scans our container images for vulnerabilities.  Internally we use Artifactory x-Ray across the components of our stack.  Our customers use their own scanning tools, and we  




## Networking

### Network Policies

### Service Mesh 

- reporting CVES
- airgap
- container scanning
- RBAC
- Secrets Management
- Pod security scanning 
- datree