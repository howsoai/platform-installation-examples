# Manually setting up platform-wide TLS with Vault and cert-manager

The following example will show how to manually configure m(TLS) between services, datastores, ingress traffic and the NATS message queue.  Additionally certificates used as the root of the OIDC provider will be generated.

Whilst it is likely simpler and more comprehensive to use a [service mesh](../linkerd/README.md) to achieve this, this example will cover much of what is needed for those who require find grained control over the PKI used for connecting all Platform components and also the values that can be used to connect to external postgres, redis or S3 compatible storage.


## Cert-manager

Cert-manager is a Kubernetes application that allows certificates objects to be created as Kubernetes resources which are automatically turned into secret objects with real certificates, by many different Certificate Authorities (let's encrypt, route53, etc).

> Note: [KOTS](../kots-existing-cluster/README.md) versions of Howso Platform bundle cert-manager and use its features to for a full internal PKI with TLS throughout.  As a recognition that for existing clusters a service mesh is often a better practice, and to simplify initial installs, this is not the case with a Helm install.

## Vault

[Hashicorp Vault](https://www.hashicorp.com/products/vault) is a popular, full featured, secrets management tool.  In this example, we're going to use it as a CA for cert-manager.

Though just a demostration of the integration, this still requires a number of steps (install, inititialization, unsealing), and configuration (PKI engine, Kubernetes auth, policies, roles).

> Note: In this example, the fundamental point of integration with Hashicorp Vault is the [Vault Issuer](./manifests/vault-issuer.yaml) which is a custom resource that cert-manager uses to issue certificates from Vault.  Swap out the `vault-issuer.yaml` with a [self-signed issuer](./manifests/self-signed-issuer.yaml) and you can achieve a working setup without installing Vault.


## Steps

### Prerequisites 

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding - a k3d cluster, with a howso namespace, logged into the Helm registry and setup the local hosts file.

In addition add the following to your /etc/hosts file:
```sh
127.0.0.1 vault.local.howso.com
```

Apply the following to get up and running quickly:
```sh
# add local.howso.com vault|pypi|api|www|management.local.howso.com to /etc/hosts 
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

Make sure to have the following tools installed:
- [helm](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [jq](https://stedolan.github.io/jq/)


### Install cert-manager

From the cert-manager [documentation](https://cert-manager.io/docs/installation/kubectl/) apply the following manifest to install cert-manager: 
```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
```

Check the cert-manager components start correctly:
```sh
kubectl get pods --namespace cert-manager
```

### Install Vault

Since we have some custom configuration we'll use a helm chart to install Vault.

Add the Hashicorp helm repository:
```sh
helm repo add hashicorp https://helm.releases.hashicorp.com
```

Install vault via Helm.  Check the [values file](./manifests/vault.yaml) for the configuration (adding the UI and ingress).
```sh
helm upgrade --install --namespace vault  --create-namespace --version 0.28.1 --values vault-certmanager/manifests/vault.yaml vault hashicorp/vault --wait 
``` 

Check the vault pod is running:
```sh
kubectl get po -n vault
```

The output should look something like this - note that it is running, but not yet ready (because it is sealed):
```txt
NAME                                    READY   STATUS    RESTARTS   AGE
vault-agent-injector-5dc9fcd4bc-zzkz2   1/1     Running   0          76s
vault-0                                 0/1     Running   0          76s
```

> Note: This demo is to show the integration with Howso Platform via cert-manager.  Securing Vault properly is deliberately not included; for instance, here a single key share is created and stored in a local file for demonstration expediency, not security.

Initialize vault, and save the key and root token.
```sh
kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > vault-init.json
```

Take a look at the output:
```sh
cat vault-init.json
```

It should look something like this.  Later commands will use [jq](https://stedolan.github.io/jq/) to grab the unseal keys and root token from this file.
```json
{
  "unseal_keys_b64": [
    "someUnsealKeyB64Value="
  ],
  "unseal_keys_hex": [
    "someUnsealKeyHexValue"
  ],
  "unseal_shares": 1,
  "unseal_threshold": 1,
  "recovery_keys_b64": [],
  "recovery_keys_hex": [],
  "recovery_keys_shares": 0,
  "recovery_keys_threshold": 0,
  "root_token": "hvs.someSecretToken"
}
```

Unseal the vault (this can be repeated if a restart seals the vault again):
```sh
kubectl exec -n vault vault-0 -- vault operator unseal $(jq -r ".unseal_keys_b64[0]" vault-init.json)
```

At any point you can check the status of the vault again (sealed should be false):
```sh
kubectl exec -n vault vault-0 -- vault status
```

Check access to the [Vault UI](https://vault.local.howso.com/), accept the certificate warning and use the root token to login:
```sh
# Go to https://vault.local.howso.com/ select Token method and paste the root token
# .. which you can get from the vault-init.json file 
jq -r ".root_token" vault-init.json
```

> Note: If you can't see the UI - troubleshoot before proceeding; the UI isn't required, but a working ingress is needed for the vault cli to connect to the Vault server.

### Install vault cli

Download the vault cli from the [Hashicorp website](https://releases.hashicorp.com/vault).  Extract the binary and move it to a location in your path.

Set the following environment variables, to be used by the cli, with connection parameters to the vault server:
```sh
export VAULT_ADDR='https://vault.local.howso.com/'
export VAULT_SKIP_VERIFY=true
```

Use the root token to login the cli to the vault:
```sh
vault login
```

### Set up Vault PKI

Different types of secrets have different secret engine backends in vault.  The PKI engine is used for certificates.  The next steps will enable it and configure a root CA.  Once enabled, it will be possible to use vault to issue certificates that are signed by this root CA.

First, enable Vault's [PKI secrets](https://developer.hashicorp.com/vault/docs/secrets/pki/setup) engine and create a root CA:

```sh
# Enable the PKI secrets engine
vault secrets enable pki

# Generate the root certificate
vault write -field=certificate pki/root/generate/internal \
     common_name="Example Root CA" \
     ttl=87600h > root-ca.crt
```

This root-ca.crt file is the public key of the root CA.  It can be used to verify certificates issued by this CA.  So adding it as a secret in Kubernetes, will allow it to be mounted into the Howso Platform components that need to verify certificates issued by Vault.

Create a secret in Kubernetes with the root CA certificate:
```sh
kubectl create secret generic platform-vault-ca \
    --from-file=ca.crt=root_ca.crt \
    -n howso
```

Configure the PKI secrets engine and create a role for issuing certificates:
```sh
# Configure the CA and CRL URLs
vault write pki/config/urls \
     issuing_certificates="http://vault.local/v1/pki/ca" \
     crl_distribution_points="http://vault.local/v1/pki/crl"

# Role for issuing ingress certificates
vault write pki/roles/ingress-certs \
     allowed_domains="local.howso.com" \
     allow_subdomains=true \
     max_ttl="720h"

# Role for issuing internal kubernetes certificates
vault write pki/roles/internal-k8s-certs \
     allowed_domains="*,svc.cluster.local" \
     allow_subdomains=true \
     allow_glob_domains=true \
     allow_any_name=true \
     enforce_hostnames=false \
     max_ttl="720h"
```

Create a [policy](./manifests/cert-manager-vault-policy.hcl) that allows cert-manager to issue certificates:
```sh
vault policy write cert-manager-policy vault-certmanager/manifests/cert-manager-vault-policy.hcl 
```

## 3. Create a Kubernetes Auth Role in Vault

Enabling Kubernetes authentication in Vault allows Kubernetes services (like cert-manager) to authenticate with Vault using Kubernetes service accounts. This is a more secure alternative to using static tokens.


Enable Kubernetes authentication in Vault and create a role for cert-manager:
```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth with the service mapped to the api server 
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc"

# Create a role for cert-manager
vault write auth/kubernetes/role/cert-manager \
    bound_service_account_names=cert-manager \
    bound_service_account_namespaces=cert-manager \
    policies=cert-manager-policy \
    ttl=1h
```

## 4. Create a Kubernetes Secret for Vault Authentication

Create a Secret in Kubernetes with the Vault root token (for demonstration purposes only, use a more secure method for a hardened setup):

```bash
kubectl create secret generic vault-token \
    --from-literal=token="$(jq -r .root_token vault-init.json)" -n howso
```

## 5. Create the cert-manager Vault Issuers

Apply the cert-manager [Issuer](./manifests/vault-issuer.yaml) manifests to create Vault Issuers in the `howso` namespace. One will deal with internal Kubernetes services, the other ingress with our orgs domain.  The Vault Issuers are for issuing certificates using the Vault PKI secrets engine.

```bash
kubectl -n howso apply -f vault-certmanager/manifests/vault-issuers.yaml
```

### Test Certificate Issuance 
Secrets containing new certificates signed by the Vault CA will be created in the `howso` namespace when the Issuers are used.  To confirm that everything is working correctly, create some test certificates:
```bash
kubectl -n howso apply -f vault-certmanager/manifests/tests-certs.yaml
```

## Verify the Certificates

Check the status of the certificate:

```bash
kubectl -n howso get certificate test-ingress-cert -n howso
kubectl -n howso get certificate test-internal-k8s-cert -n howso
```

You should see the certificates with True set in the Ready column.

## Setup Howso Platform

With cert-manager and Vault set up, any Howso Platform component that requires a certificate, or a communication path that could use TLS or mTLS can use cert-manager Certificate api objects to create the required certificates.

Follow [these docs for a full](./howso-platform-full.md) TLS/mTLS throughout setup, but to avoid too a lot of changes at once, the recommended approach is to follow instructions for individual components and sections to build up the setup incrementally.

- [Redis](./redis-tls.md)
- [Postgres](./postgres-tls.md)
- [NATS](./nats-tls.md)
- [Minio](./minio-tls.md)
- [Ingress](./ingress-tls.md)
- [OIDC](./oidc-tls.md)