# Domain Customization

The Howso Platform routes to services using different subdomains under a shared parent domain. 

Each subdomains must be one label, under a fully qualified domain name (FQDN) - the parent domain.

It is simplest to pick a parent domain for the sole use of the Howso Platform and use the default subdomains.  However it is possible to customize as follows: 

## Parent Domain

Set the parent domain for your Howso Platform instance:

```yaml
domain: howso-platform.example.com
```

### Parent Domain Redirect

The parent domain will just redirect to the front page of the Howso Platform, but you can disable this redirect if desired, and no ingress rules will be created for the parent domain.

```yaml
redirectParentDomain: false
```

## Subdomain Customization

You can customize subdomains for specific services:
i.e. 

```yaml
pypi:
  subdomain: howso-pypi
api:
  subdomain: howso-api
```

These settings allow you to tailor the URLs for different components of the Howso Platform typically this might be done to avoid a conflict with an existing service. 

For a complete example of a values file for configuring domain customization, see the [custom-domain.yaml](./manifests/custom-domain.yaml), this example will result in the following subdomains:

Main entrypoint (parent) domain:  https://howso-platform.example.com
UI subdomain: https://howso-www.howso-platform.example.com
API subdomain: https://howso-api.howso-platform.example.com
UMS/Auth subdomain: https://howso-auth.howso-platform.example.com
PyPi subdomain: https://howso-pypi.howso-platform.example.com