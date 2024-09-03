# Configure Howso Platform with Redis and mTLS
## Install Howso Platform

This example assumes that [Vault and cert-manager](./README.md) are already installed and configured.

This example will start with a working, non-tls, Howso Platform, then adjust the configuration needed for Redis, Howso Platform and Cert-Manager to work together with mTLS.

See [here](../common/README.md#basic-helm-install) for a quick start (skipping the initial cluster creation, that was done during the Vault install) and confirm the Howso Platform is running [correctly](../common/README.md#create-client-environment).

## Redis Setup

### Create the Redis Server Certificate

The Redis server will need a certificate to secure the connection.  Takes a look at the [manifest](./manifests/redis-tls/redis-server-certificate.yaml) for the certificate.  Note the use of the [vault-issuer](./manifests/vault-issuer.yaml) to issue the certificate.  The dnsNames are set to the redis service names, the usage is set to server auth.

```sh
kubectl apply -f vault-certmanager/manifests/redis-tls/redis-server-cert.yaml
```

Check the certificate is issued and ready

```sh
kubectl get certificate platform-redis-server-cert
```

### Redeploy the Redis Helm Install with TLS

Check out the [manifest](./manifests/redis-tls/redis.yaml) for the Redis Helm install.
The use of `authClients` mandates that clients also use a certificate.

Optionally, use [Helm diff](https://github.com/databus23/helm-diff?tab=readme-ov-file#install) to see the changes that will be made.

```sh
helm diff upgrade --install platform-redis oci://registry.how.so/howso-platform/stable/redis --namespace howso --values vault-certmanager/manifests/redis-tls/redis.yaml
```

Since a volume is added to the statefulset, it is not a supported upgrade path.  In this case, we'll delete the existing Redis and reinstall.

```sh
helm delete platform-redis -n howso
helm install platform-redis oci://registry.how.so/howso-platform/stable/redis --namespace howso --values vault-certmanager/manifests/redis-tls/redis.yaml --wait
```

### Check the installation

Check the logs of the Redis master.
```sh
kubectl logs -f platform-redis-master-0 -n howso
```

The startup logs should show the Redis server is ready and configured for TLS.
```sh
1:C 02 Sep 2024 11:53:21.842 * oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
1:C 02 Sep 2024 11:53:21.842 * Redis version=7.2.5, bits=64, commit=00000000, modified=0, pid=1, just started
1:C 02 Sep 2024 11:53:21.842 * Configuration loaded
1:M 02 Sep 2024 11:53:21.842 * monotonic clock: POSIX clock_gettime
1:M 02 Sep 2024 11:53:21.848 * Running mode=standalone, port=6379.
1:M 02 Sep 2024 11:53:22.043 * Server initialized
1:M 02 Sep 2024 11:53:22.044 * Ready to accept connections tls
```

## Howso Platform Setup


### Create a client redis certificate

```sh
kubectl apply -f vault-certmanager/manifests/redis-tls/redis-client-cert.yaml
```

Check out the [manifest](./manifests/howso-tls/howso.yaml) for the Howso Platform Helm install.

```sh
helm upgrade --install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values vault-certmanager/manifests/redis-tls/howso-platform.yaml
```


## Confirm it works

```sh
python -m howso.utilities.installation_verification
```