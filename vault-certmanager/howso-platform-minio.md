# Configure Howso Platform with MinIO and TLS

## Install Howso Platform

This example assumes that [Vault and cert-manager](./README.md) are already installed and configured.

This example starts with a working, non-TLS Howso Platform. We'll then adjust the configuration needed for MinIO, Howso Platform, and Cert-Manager to work together with TLS.

See [here](../common/README.md#basic-helm-install) for a quick start (skipping the initial cluster creation, that was done during the Vault install) and confirm the Howso Platform is running [correctly](../common/README.md#create-client-environment).

## MinIO Setup

### Create the MinIO Server Certificate

The MinIO server needs a certificate to secure the connection. Take a look at the [manifest](./manifests/minio-tls/minio-server-cert.yaml) for the certificate. Note the use of the [vault-issuer](./manifests/vault-issuer.yaml) to issue the certificate. The dnsNames are set to the MinIO service names, and the usage is set to server auth.

```sh
kubectl apply -f vault-certmanager/manifests/minio-tls/minio-server-cert.yaml
```

Check the certificate is issued and ready:

```sh
kubectl get certificate platform-minio-server-cert -n howso
```

### Redeploy the MinIO Helm Install with TLS

Check out the [manifest](./manifests/minio-tls/minio.yaml) for the MinIO Helm install.
The `tls.enabled` setting enables TLS for the MinIO server.

Optionally, use [Helm diff](https://github.com/databus23/helm-diff?tab=readme-ov-file#install) to see the changes that will be made:

```sh
helm diff upgrade --install platform-minio oci://registry.how.so/howso-platform/stable/minio --namespace howso --values vault-certmanager/manifests/minio-tls/minio.yaml
```

Since we're changing the TLS configuration, it's safer to delete the existing MinIO and reinstall:

```sh
helm delete platform-minio -n howso
helm install platform-minio oci://registry.how.so/howso-platform/stable/minio --namespace howso --values vault-certmanager/manifests/minio-tls/minio.yaml --wait
```

### Check the installation

Check the logs of the MinIO server:

```sh
kubectl logs -f deployment/platform-minio -n howso
```

The startup logs should show that MinIO is ready and configured for TLS:

```
MinIO Object Storage Server
Copyright: 2015-2023 MinIO, Inc.
License: GNU AGPLv3 <https://www.gnu.org/licenses/agpl-3.0.html>
Version: RELEASE.2023-09-02T21-00-21Z (go1.20.7 linux/amd64)

Status:         1 Online, 0 Offline. 
API: https://:9000  https://platform-minio:9000 
Console: https://:9001 https://platform-minio:9001

Documentation: https://docs.min.io
```

## Howso Platform Setup

### Update Howso Platform Configuration

Check out the [manifest](./manifests/minio-tls/howso-platform.yaml) for the Howso Platform Helm install. This configuration updates the MinIO connection details to use TLS.

```sh
helm upgrade --install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values vault-certmanager/manifests/minio-tls/howso-platform.yaml
```

## Confirm it works

Use the Howso Platform installation verification utility:

```sh
python -m howso.utilities.installation_verification
```

Additionally, you can check the MinIO connection by running a pod with the MinIO client (mc) and attempting to connect:

```sh
kubectl run -it --rm --image=minio/mc --namespace=howso minio-client -- /bin/sh

mc alias set myminio https://platform-minio:9000 YOUR_MINIO_ACCESS_KEY YOUR_MINIO_SECRET_KEY --insecure
mc ls myminio
```

Replace `YOUR_MINIO_ACCESS_KEY` and `YOUR_MINIO_SECRET_KEY` with your actual MinIO credentials. The `--insecure` flag is used here because we're using self-signed certificates. In a production environment with proper certificates, you would omit this flag.

If the connection is successful, you'll see a list of buckets (if any) in your MinIO instance. You can then exit with `exit`.

Remember to securely manage your MinIO credentials and avoid exposing them in logs or to unauthorized users.