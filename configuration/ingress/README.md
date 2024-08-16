# Ingress Configuration

This section covers ingress configuration options for the Howso Platform.

## Overview

The Howso Platform uses ingress to manage external access to services in your Kubernetes cluster. Key configuration options include:

## Ingress Class

Many ingress controllers will only process ingresses with a specific `ingressClassName`.

Specify this with the `ingress.ingressClassName` key in the Howso Platform values.  It will be used for all ingresses.  The default value is `null` - which will leave it unset.

> Note: If a default ingress is set for the cluster, with the `ingressclass.kubernetes.io/is-default-class: "true"` then it is not necessary to set the `ingress.ingressClassName` value.

## Domain Configuration

See the [documentation here](./domain-customization/README.md) for information about configuring the domains used by the Howso Platform.

## TLS Certificates

These [examples](../../custom-ingress-cert/README.md) show how to configure the Howso Platform to use custom TLS certificates.

## TLS Termination at the application

This [example](../../application-tls-termination/README.md) shows how to configure the Howso Platform to encrypt traffic between the ingress and the application. 

## Specific Ingress Types

Configuration pertinant to specific ingress types:

[AWS ALB configuration](./alb/README.md)

