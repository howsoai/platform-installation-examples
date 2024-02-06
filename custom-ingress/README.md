# Ingress TLS

Out of the box the Howso Platform will create a certificate `platform-ingress-tls` which is signed by the platform CA (a self-signed root certificate).  This certificate will be offered up by the ingress controller to incoming requests through the browser or python client to any of the domains of the platform.

If the platform certificate [extracted](../common/README.md#extract-the-platform-ca-cert)is added to root trust stores of the operating system (and/or browser) then the browser will not show a warning when visiting the platform.  The python client configuration (`howso.yml`) can be [updated to trust the platform certificate](../common/README.md#update-the-howsoyml-to-trust-the-platform-ca) as well.

A common customization is to change the certificates offered up by the ingress controller to custom certs; this opens an opportunity for them to be signed by a globally trusted root, or corporate CA.  The Howso Platform can be configured to reference custom ingress provided in a kuberenetes secret.

For those using cert-manager, the Howso Platform can be configured to annotate the ingress to use a named issuer.  This configuration can leverege cert-manager's suite of cabilities, including the ability to get letsencrypt certificates for public DNS, and automatically roll expiry dates. 

## Custom Ingress TLS 

With `tls.key` and `tls.crt` files, create a kubernetes secret.

```sh
kubectl create secret tls platform-custom-ingress-tls --key tls.key --cert tls.crt
```

Augment the values file for the howso-platform chart to reference the custom ingress secret. 
```yaml
overrideIngressCerts:
  secretName: platform-custom-ingress-tls
```

## Certmanager Issuer Ingress TLS

Create a ClusterIssuer or Issuer according to the cert-manager [documentation](https://cert-manager.io/docs/concepts/issuer/).  


Augment the values file for the howso-platform chart to reference the custom ingress secret. 

In this example myCustomIssuer is a ClusterIssuer. 

```yaml
overrideIngressCerts:
  enabled: true
internalPKI:
  ingressCertIssuer: myCustomIssuer 
  useClusterIssuer: true 
```






## Trusting the platform CA