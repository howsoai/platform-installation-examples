# Configure Howso Platform with PostgreSQL and TLS

## Install Howso Platform

This example assumes that [Vault and cert-manager](./README.md) are already installed and configured.

This example starts with a working, non-TLS Howso Platform. We'll then adjust the configuration needed for PostgreSQL, Howso Platform, and Cert-Manager to work together with TLS.

See [here](../common/README.md#basic-helm-install) for a quick start (skipping the initial cluster creation, that was done during the Vault install) and confirm the Howso Platform is running [correctly](../common/README.md#create-client-environment).

## PostgreSQL Setup

### Create the PostgreSQL Server Certificate

The PostgreSQL server needs a certificate to secure the connection. Take a look at the [manifest](./manifests/postgres-tls/postgres-server-cert.yaml) for the certificate. Note the use of the [vault-issuer](./manifests/vault-issuer.yaml) to issue the certificate. The dnsNames are set to the PostgreSQL service names, and the usage is set to server auth.

```sh
kubectl apply -f vault-certmanager/manifests/postgres-tls/postgres-server-cert.yaml
```

Check the certificate is issued and ready:
```sh
kubectl get certificate postgres-server-cert-n howso
```

### Redeploy the PostgreSQL Helm Install with TLS

Check out the [manifest](./manifests/postgres-tls/postgres.yaml) for the PostgreSQL Helm install.
The `tls.enabled` setting enables TLS for the PostgreSQL server.

Optionally, use [Helm diff](https://github.com/databus23/helm-diff?tab=readme-ov-file#install) to see the changes that will be made:

```sh
helm diff upgrade --install platform-postgres oci://registry.how.so/howso-platform/stable/postgresql --namespace howso --values vault-certmanager/manifests/postgres-tls/postgres.yaml
```

Apply the changes:

```sh
helm upgrade --install platform-postgres oci://registry.how.so/howso-platform/stable/postgresql --namespace howso --values vault-certmanager/manifests/postgres-tls/postgres.yaml --wait
```

### Check the installation

Check the logs of the PostgreSQL primary:

```sh
kubectl logs -f platform-postgres-postgresql-0 -n howso
```

The startup logs should show that PostgreSQL is ready and configured for TLS:

```
postgresql 12:19:21.36 INFO  ==>
postgresql 12:19:21.37 INFO  ==> Welcome to the Bitnami postgresql container
postgresql 12:19:21.37 INFO  ==> Subscribe to project updates by watching https://github.com/bitnami/containers
postgresql 12:19:21.37 INFO  ==> Submit issues and feature requests at https://github.com/bitnami/containers/issues
postgresql 12:19:21.37 INFO  ==> Upgrade to Tanzu Application Catalog for production environments to access custom-configured and pre-packaged software components. Gain enhanced features, including Software Bill of Materials (SBOM), CVE scan result reports, and VEX documents. To learn more, visit https://bitnami.com/enterprise
postgresql 12:19:21.37 INFO  ==>
postgresql 12:19:21.48 INFO  ==> ** Starting PostgreSQL setup **
postgresql 12:19:21.66 INFO  ==> Validating settings in POSTGRESQL_* env vars..
postgresql 12:19:21.67 INFO  ==> Cleaning stale /bitnami/postgresql/data/postmaster.pid file
postgresql 12:19:21.67 INFO  ==> Loading custom pre-init scripts...
postgresql 12:19:21.77 INFO  ==> Initializing PostgreSQL database...
postgresql 12:19:21.78 INFO  ==> pg_hba.conf file not detected. Generating it...
postgresql 12:19:21.78 INFO  ==> Generating local authentication configuration
postgresql 12:19:21.96 INFO  ==> Deploying PostgreSQL with persisted data...
postgresql 12:19:22.06 INFO  ==> Configuring replication parameters
postgresql 12:19:22.17 INFO  ==> Configuring fsync
postgresql 12:19:22.18 INFO  ==> Configuring TLS
chmod: changing permissions of '/opt/bitnami/postgresql/certs/tls.key': Read-only file system
postgresql 12:19:22.26 WARN  ==> Could not set compulsory permissions (600) on file /opt/bitnami/postgresql/certs/tls.key
postgresql 12:19:22.37 INFO  ==> Configuring synchronous_replication
postgresql 12:19:22.37 INFO  ==> Enabling TLS Client authentication
postgresql 12:19:22.56 INFO  ==> Loading custom scripts...
postgresql 12:19:22.57 INFO  ==> Enabling remote connections
postgresql 12:19:22.58 INFO  ==> ** PostgreSQL setup finished! **
```

Since the Howso Platform is not yet configured for tls to the db, the logs will show failed connections.


## Howso Platform Setup

### Create a client PostgreSQL certificate

```sh
kubectl apply -f vault-certmanager/manifests/postgres-tls/postgres-client-cert.yaml
```

Check the certificate is issued and ready:
```sh
kubectl get certificate platform-postgres-client-tls -n howso
```

Check out the [manifest](./manifests/postgres-tls/howso-platform.yaml) for the Howso Platform Helm install.  Note the serverCertChainSecretName is set to the vault root ca created directly as a secret during the [Vault setup](../vault-certmanager/README.md#vault).

> Note: If building on top of [redis](howso-platform-redis.md), [nats](howso-platform-nats.md), etc - augment helm commands with additional the values files from those examples to (you can use multiple --values parameters in a helm command).

```sh
helm upgrade --install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values vault-certmanager/manifests/postgres-tls/howso-platform.yaml --wait
```

## Confirm it works

Use the Howso Platform installation verification utility:

```sh
python -m howso.utilities.installation_verification
```
