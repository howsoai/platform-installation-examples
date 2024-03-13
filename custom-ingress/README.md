## Ingress Certs

Howso Platform uses Ingress resources to expose several services to users via HTTPS.

The default TLS certificates used by the Howso Platform are created by the `platform-cert-generation-initial` job shortly after the installation and managed on an ongoing basis by the `platform-cert-generation` cronjob.  These certificates are signed by a Certificate Authority (CA) that is created and stored as a secret at `platform-ca`.  This CA can be [extracted and trusted by users](../common/README.md#trust-the-certs) so that a browser or Python client will trust and verify the Howso Platform's certificates. 

Ingress certificates signed by this platform CA will be offered up by the ingress controller to incoming requests through the browser or Python client, to any of the domains of the platform.  Trusting the CA, rather than the ingress certificate directly, will remove the need to trust individual certificates, and certificates that have been rotated will be automatically trusted. 

> Howso Platform must be accessed via HTTPS; HTTP only access is not supported and is expected to break elements of the application, including UI authentication.  HSTS headers will help enforce this, users may also wish to add additional annotations (via the [chart values](../common/README.md#howso-platform-helm-chart-values)) to the Ingress resources to force redirects.


To use custom ingress certificates, with your own CA, there are two options:
- Configure a custom Ingress TLS secret 
- Configure a cert-manager issuer


### Custom Ingress Certs
The Howso Platform can be configured to use a custom ingress certificate provided in a Kubernetes secret; allowing the use of a certificate signed with a corporate CA, or a globally trusted root CA.  

> Note: The following [step CLI](https://smallstep.com/docs/step-cli/) command is provided as an example to help you quickly generate a self-signed certificate and private key, without having to deal with your network's PKI.

```sh
# Generate a self-signed certificate and private key .. just for testing
step certificate create local.howso.com tls.crt tls.key --profile self-signed --not-after 8760h --no-password --insecure --subtle
```

With `tls.key` and `tls.crt` files, create a Kubernetes secret.

```sh
# Generate a self-signed certificate and private key - just for testing
step certificate create local.howso.com tls.crt tls.key --profile self-signed --not-after 8760h --no-password --insecure --subtle \
  --san www.local.howso.com --san management.local.howso.com --san api.local.howso.com --san pypi.local.howso.com
```

Augment the values file for the howso-platform chart to reference the custom ingress secret. 
```yaml
overrideIngressCerts:
  secretName: platform-custom-ingress-tls
```

If you install the [helm basic example](../helm-basic/README.md) with the above configuration, you can update to use the custom ingress certs with the following command. 
```sh
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values custom-ingress/manifests/howso-platform.yaml 
```

Check the certificate is being used by inspecting the ingress.
```sh
step certificate inspect https://local.howso.com --insecure
```

### Cert-Manager Issuer
For those using cert-manager, the Howso Platform can be configured to annotate the ingress to use a named issuer.  This configuration can leverage Cert-manager's suite of capabilities, including the ability to get [Let's Encrypt](https://letsencrypt.org/) certificates for public DNS, and automatically roll expiry dates. 

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


