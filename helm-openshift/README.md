# Helm Installation for Howso Platform on OpenShift

## Introduction
This guide outlines the process of deploying the Howso Platform using Helm in OpenShift environments. It demonstrates how to configure Helm charts specifically for OpenShift and addresses unique considerations for these installations.

## Overview
Deploying on OpenShift requires tailored configurations to accommodate its security model and operational paradigms. This documentation provides steps to modify Helm values for OpenShift and highlights best practices for a successful deployment.

## Complexities of OpenShift Installs
OpenShift, with its security-focused architecture, introduces complexities not present in standard Kubernetes environments. Key considerations include:

- **Security Context Constraints (SCCs)**: OpenShift's SCCs often require additional configurations for pods to run with the necessary privileges.
- **Network Policies**: Adjustments to network policies may be necessary to enable proper communication between services.
- **Route and Ingress Management**: OpenShift's handling of routes and ingress resources can differ from standard Kubernetes, necessitating specific configurations.

## Customizing Helm Values for OpenShift
Copy the customized Helm values file configured for OpenShift:
```bash
cp ./minio/config/values-patch-openshift.yaml /home/dom/workspaces/howso-platform-start/components/platform-installation-examples/helm-openshift/manifests/
```
## Alternative Installation Without KOTS and CertManager
For a more streamlined setup in OpenShift, you can opt to install the Howso Platform using just namespace permissions. This method eliminates the need for KOTS and CertManager by directly installing the required CRDs, using the `customResourceDefinitions.skip` option during the platform's installation.

### Extracting and Applying the CRD for Separate Installation
To extract and apply the CRD directly, use the following command, substituting `$CHART_URI` with the appropriate Helm chart URI:
```bash
helm template $CHART_URI --show-only templates/crds/trainee-crd.yaml | kubectl apply -f -
```

This command uses helm template to generate the necessary CRD manifest from the Howso Platform Helm chart and applies it using kubectl. It facilitates a targeted and namespace-specific installation approach, fitting for OpenShift environments.
