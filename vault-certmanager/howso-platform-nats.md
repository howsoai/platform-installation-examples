# Configure Howso Platform with NATS and TLS

## Install Howso Platform

This example starts with a working, non-TLS Howso Platform. We'll then adjust the configuration needed for NATS, Howso Platform, and Cert-Manager to work together with TLS.

See [here](../common/README.md#basic-helm-install) for a quick start (skipping the initial cluster creation, that was done during the Vault install) and confirm the Howso Platform is running [correctly](../common/README.md#create-client-environment).

## NATS Setup

### Create the NATS Server Certificate

The NATS server needs a certificate to secure the connection. Take a look at the [manifest](./manifests/nats-tls/nats-server-cert.yaml) for the certificate. Note the use of the [vault-issuer](./manifests/vault-issuer.yaml) to issue the certificate. The dnsNames are set to the NATS service names, and the usage is set to server auth.

```sh
kubectl apply -f vault-certmanager/manifests/nats-tls/nats-server-cert.yaml
```

Check the certificate is issued and ready:

```sh
kubectl get certificate nats-server-tls -n howso
```

### Create the NATS Cluster Certificate

For NATS cluster communication, we need an additional certificate. Apply the manifest for the cluster certificate:

```sh
kubectl apply -f vault-certmanager/manifests/nats-tls/nats-cluster-cert.yaml
```

Check the cluster certificate is issued and ready:

```sh
kubectl get certificate nats-cluster-tls -n howso
```

### Redeploy the NATS Helm Install with TLS

Check out the [manifest](./manifests/nats-tls/nats.yaml) for the NATS Helm install.
The configuration enables TLS for both client-server and cluster communication.

Optionally, use [Helm diff](https://github.com/databus23/helm-diff?tab=readme-ov-file#install) to see the changes that will be made:

```sh
helm diff upgrade --install platform-nats oci://registry.how.so/howso-platform/stable/nats --namespace howso --values vault-certmanager/manifests/nats-tls/nats.yaml
```

Now, let's upgrade the NATS installation:

```sh
helm upgrade --install platform-nats oci://registry.how.so/howso-platform/stable/nats --namespace howso --values vault-certmanager/manifests/nats-tls/nats.yaml --wait
```

### Check the installation

Check the logs of one of the NATS pods:

```sh
kubectl logs -f deployment/platform-nats -n howso
```

The startup logs should show that NATS is ready and configured for TLS:

```
[1] 2024/09/02 13:00:00.000000 [INF] Starting nats-server
[1] 2024/09/02 13:00:00.000000 [INF] Version:  2.9.21
[1] 2024/09/02 13:00:00.000000 [INF] Server Name:  NAABCDEFGHIJK
[1] 2024/09/02 13:00:00.000000 [INF] Listening for client connections on 0.0.0.0:4222
[1] 2024/09/02 13:00:00.000000 [INF] TLS required for client connections
[1] 2024/09/02 13:00:00.000000 [INF] Server is ready
```

## Howso Platform Setup

### Create Client Certificates for Howso Platform Components

Several Howso Platform components need to connect to NATS. We'll create client certificates for each:

```sh
kubectl apply -f vault-certmanager/manifests/nats-tls/platform-api-v3-nats-client-cert.yaml
kubectl apply -f vault-certmanager/manifests/nats-tls/platform-worker-nats-client-cert.yaml
kubectl apply -f vault-certmanager/manifests/nats-tls/platform-sms-nats-client-cert.yaml
kubectl apply -f vault-certmanager/manifests/nats-tls/platform-ums-nats-client-cert.yaml
kubectl apply -f vault-certmanager/manifests/nats-tls/platform-notsvc-nats-client-cert.yaml
kubectl apply -f vault-certmanager/manifests/nats-tls/platform-operator-nats-client-cert.yaml
```

### Update Howso Platform Configuration

Check out the [manifest](./manifests/nats-tls/howso-platform.yaml) for the Howso Platform Helm install. This configuration updates the NATS connection details to use TLS for all components.

```sh
helm upgrade --install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values vault-certmanager/manifests/nats-tls/howso-platform.yaml
```

## Confirm it works

Use the Howso Platform installation verification utility:

```sh
python -m howso.utilities.installation_verification
```

Additionally, you can check the NATS connection by running a pod with the NATS CLI and attempting to connect:

```sh
kubectl run -it --rm --image=natsio/nats-box:latest --namespace=howso nats-box -- /bin/sh

nats-box:~$ nats context save secure --server nats://platform-nats:4222 --creds /path/to/user.creds --tlsca /path/to/ca.pem
nats-box:~$ nats context select secure
nats-box:~$ nats sub test &
nats-box:~$ nats pub test "hello world"
```

Replace `/path/to/user.creds` and `/path/to/ca.pem` with the actual paths to your NATS user credentials and CA certificate.

If the connection is successful, you should see the "hello world" message received by the subscriber. You can then exit with `exit`.

Remember to securely manage your NATS credentials and avoid exposing them in logs or to unauthorized users.

## Troubleshooting

If you encounter issues:

1. Verify all certificates are in the "Ready" state:
   ```sh
   kubectl get certificates -n howso
   ```

2. Check NATS server logs for TLS-related issues:
   ```sh
   kubectl logs -f deployment/platform-nats -n howso
   ```

3. Ensure all Howso Platform components have been updated with the correct TLS configuration.

4. If a component is failing to connect, check its logs for TLS-related errors:
   ```sh
   kubectl logs -f deployment/platform-component-name -n howso
   ```

Replace `platform-component-name` with the actual name of the component (e.g., platform-api-v3, platform-worker, etc.)