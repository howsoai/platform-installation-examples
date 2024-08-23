# Manually setting up inter service TLS with Vault and cert-manager

It is simpler to use a [service mesh](../linkerd/README.md) to achieve this.  But this example should indicate for those who need to manually configure mTLS connection, what the configuration looks like.

## Cert-manager
Cert-manager is a kubernetes application that allows certificates objects to be created as Kubernetes resources, which can then be automatically turned into real certificates, by many different CA (let's encrypt, route53, etc).  It is very heavily used.  Earlier version of Howso Platform required cert-manager to be installed, and used its features to have a full internal PKI.  To simplify the helm install, that is no longer the case, but if you do wish to manually configure mTLS between services and datastores, cert-manager is the tool to use.


## Vault
Vault is a full featured secrets management tool.  In this example, we're going to use it as a CA for cert-manager.


## Steps

### Prerequisites 

Ensure you have completed the [prerequisites](../prereqs/README.md) before proceeding, have a k3d cluster running, with a howso namespace, and are logged into the Helm registry, and have setup the local hosts file.

Apply the following to get up and running quickly. 
```sh
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts 
# helm registry login registry.how.so --username your_email@example.com --password your_license_id 
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl create namespace howso
```

In addition add the following to your /etc/hosts file:
```sh
127.0.0.1 vault.local.howso.com
```

### Install Cert-manager

From the cert-manager [documentation](https://cert-manager.io/docs/installation/kubectl/), installation is often done by directly applying a manifest file. 

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
```

Check that they start correctly:
```sh
kubectl get pods --namespace cert-manager
```

### Install Vault

Since we have some custom configuration, we'll use a helm chart to install Vault.

Add the Hashicorp helm repository:
```sh
helm repo add hashicorp https://helm.releases.hashicorp.com
```

Install vault via Helm.  Check the [values file](./manifests/vault.yaml) for the configuration (adding the UI and ingress).
```sh
helm upgrade --install --namespace vault  --create-namespace --version 0.28.1 --values vault-certmanager/manifests/vault.yaml vault hashicorp/vault --wait 
``` 

> Note: This is a demo to show the integration with Howso Platform and cert-manger securing Vault properly is deliberately not part of the example.

Initialize vault, and save the key and root token.
```sh
kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > vault-init.json
```

Take a look at the output:
```sh
cat vault-init.json
```

It should look something like this.  Later commands will use [jq](https://stedolan.github.io/jq/) to grab the unseal keys and root token.
```json
{
  "unseal_keys_b64": [
    "someUnsealKeyB64Value"
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

Unseal the vault:
```sh
kubectl exec -n vault vault-0 -- vault operator unseal $(jq -r ".unseal_keys_b64[0]" vault-init.json)
```

Check the status of the vault (sealed should be false):
```sh
kubectl exec -n vault vault-0 -- vault status
```

Check the [UI](https://vault.local.howso.com/) and use the root token to login.

```sh
jq -r ".root_token" vault-init.json
```

> Note: If you can't see the UI - troubleshoot before proceeding.

### Install vault cli

Download the vault cli from the [Hashicorp website](https://releases.hashicorp.com/vault).  Extract the binary and move it to a location in your path.


Set the following environment variables, so all calls to the cli don't have to.
```sh
export VAULT_ADDR='https://vault.local.howso.com/'
export VAULT_SKIP_VERIFY=true
```

```sh
vault login
```

### Set up Vault PKI

Different types of secrets, have different secret engines in vault.  The PKI engine is used for certificates.  The next steps will enable it, and configure a root CA.  Once done, it will be possible to use it to issue certificates that are signed by the root CA.

First, we need to set up Vault's [PKI secrets](https://developer.hashicorp.com/vault/docs/secrets/pki/setup) engine and create a root CA.

```sh
# Enable the PKI secrets engine
vault secrets enable pki

# Generate the root certificate
vault write -field=certificate pki/root/generate/internal \
     common_name="Example Root CA" \
     ttl=87600h > root_ca.crt

#Configure the CA and CRL URLs
vault write pki/config/urls \
     issuing_certificates="http://vault.local/v1/pki/ca" \
     crl_distribution_points="http://vault.local/v1/pki/crl"

# Create a role for issuing certificates
vault write pki/roles/example-dot-com \
     allowed_domains="example.com" \
     allow_subdomains=true \
     max_ttl="720h"
```

Create a policy that allows cert-manager to issue certificates:
TODO use manifest
```sh
cat <<EOF | vault policy write cert-manager-policy -
path "pki*"                        { capabilities = ["read", "list"] }
path "pki/sign/example-dot-com"    { capabilities = ["create", "update"] }
path "pki/issue/example-dot-com"   { capabilities = ["create"] }
EOF
```

## 3. Create a Kubernetes Auth Role in Vault

Enable Kubernetes authentication in Vault and create a role for cert-manager:
 It allows Kubernetes services (like cert-manager) to authenticate with Vault using Kubernetes service accounts. This is more secure than using static tokens.
Authorization: It defines what actions the authenticated entity can perform in Vault, by associating the role with specific Vault policies.
Trust relationship: It establishes a trust relationship between your Kubernetes cluster and Vault.

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure Kubernetes auth
## TODO - What does this really achieve?
KUBE_API_SERVER="https://kubernetes.default.svc"
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

Create a Secret in Kubernetes with the Vault root token (for demonstration purposes only, use a more secure method in production):

```bash
kubectl create secret generic vault-token \
    --from-literal=token="$(jq -r .root_token vault-init.json)" -n howso
```

## 5. Create the Vault Issuer

Apply the [Issuer](./manifests/vault-issuer.yaml) manifest to create a Vault Issuer in the `cert-manager` namespace. The Vault Issuer is responsible for issuing certificates using the Vault PKI secrets engine.

```bash
kubectl apply -f vault-certmanager/manifests/vault-issuer.yaml
```

### Test Certificate Issuance 
```bash
kubectl apply -f vault-certmanager/manifests/tests-cert.yaml
```

## 7. Verify the Certificate

Check the status of the certificate:

```bash
kubectl get certificate example-com -n howso
```

You should see the certificate in a "Ready" state.

## Setup Howso Platform

With cert-manager and Vault set up, any Howso Platform component that requires a certificate, or communicates path that could use TLS or mTLS can use Certificate api objects to create the certificates.

There is a [full](./howso-platform-full.md) TLS/mTLS throughout setup, but there is also broken down instructions for each components.

- [Redis](./howso-platform-redis.md)
- [Postgres](./howso-platform-postgres.md)
- [NATS](./howso-platform-nats.md)
- [Minio](./howso-platform-minio.md)
- [Ingress](./howso-platform-ingress.md)
- [OIDC](./howso-platform-oidc.md)