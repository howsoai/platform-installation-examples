
## Install Howso Platform

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
kubectl get certificate redis-server-cert
```