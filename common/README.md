# Howso Platform Examples - Common Setup Steps

## Create Client Environment

### Login to the Howso Platform

Navigate to the User Management Service (UMS) first.  Proceed passed the certificate warning.  Login with the default admin credentials (platform-admin/platform).  You will be prompted to change the password.

https://management.local.howso.com/

> Note.  With a KOTS install driven via the UI - the initial password won't be the default, but should be retrieved from the KOTS admin configuration screen.

As you navigate you will be redirected to other subdomains - each of which will have a certificate warning to accept.  Calls to the _api_ sub-domain are cross-domain (accessed from the browser from another domain), so navigate directly https://api.local.howso.com/, to avoid hidden certificate errors.

> Note.  By default the ingress certificate(s) offered by the Howso Platform will be signed by a Certificate Authority, stored as a secret at platform-ca, which can be extracted and trusted.  It is possible to override this behavior and use a custom ingress certificate.


### Create Client Credentials

This is just a quick setup to test the installation.  The platform admin user wouldn't typically have client credentials, but would be used to bootstrap other users.
 - From the Home (Projects Page) > Create New Project > Project Name > "Test Project".
 - From Howso Admin drop-down > My Account > Preferences > Default Project > "Test Project" > Save
 - From Howso Admin drop-down > Credentials > New Credential > "test" > Create
 - Copy|Download as howso.yml to `~/.howso/howso.yml` or in your local working directory.

Either [Trust the Certs](#trust-the-certs) or [Disable SSL Verification](#disable-ssl-verification) before proceeding.

### Disable SSL Verification

Edit the `howso.yml` file and set `verify_ssl: false.


### Trust the Certs

The Howso Platform python client uses the _certifi_ package for the trusted root certs, not the operating system trust store.  Therefore, to trust the platform ca - we'll extract it from the platform and then set it explicitly as trusted in our `howso.yml`

#### Extract the platform CA cert

With kubectl access, you can retrieve the platform cert from the ca secret.

```sh
kubectl -n howso get secrets platform-ca -ojson | jq -r '.data."tls.crt"' | base64 -d > howso-platform.crt
```

Alternatively, download it from https://www.local.howso.com/ca-crt.txt (with wget, curl, a browser, etc) and save it as `howso-platform.crt`.

#### Update the howso.yml to trust the platform CA

- Update the howso.yml with a full path to the cert file, under key `security.ssl_ca_cert`.  i.e.
```yaml
security:
    ssl_ca_cert: /full/path/howso-platform.crt
    ...
howso:
  ...
```

### Create Python environment

- Create a Python virtual environment using your preferred method.

- Navigate to Client Setup tab.

- Copy the pip install command, and run in your new virtual environment.
i.e.
```sh
pip install -U --trusted-host pypi.local.howso.com --extra-index-url https://mySecretPypiToken@pypi.local.howso.com/simple/ howso-platform-client[full]
```
> Note: A productionized install would create a secret for the Platform PyPi server token - above is the default.

### Test the install

Run the verification script to ensure everything is working.
```sh
python -m howso.utilities.installation_verification
```

> Note.  If you run `kubectl get po -n howso` from another terminal, you can watch the worker pods come online as the verification script runs.

## Troubleshooting

### Howso Platform Helm Chart values

- View the [Helm values](https://helm.sh/docs/chart_template_guide/values_files/) for the howso-platform chart.
```sh
helm show values oci://registry.how.so/howso-platform/stable/howso-platform | less
```

### Additional Documentation

For assistance, consult the documentation:-

- [Howso Platform](https://portal.howso.com)
- [Helm](https://helm.sh/docs/)
- [Argo CD](https://argoproj.github.io/argo-cd/)
- [Bitnami PostgreSQL Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [Bitnami Redis Chart](https://github.com/bitnami/charts/tree/main/bitnami/redis)
- [MinIO Community Chart](https://github.com/minio/minio/tree/master/helm/minio)
- [NATS Chart](https://github.com/nats-io/k8s/tree/main/helm/charts/nats)

### Howso Platform Support
Please reach out to Howso Platform support via email (support@howso.com), or through the [Howso Customer Portal](https://portal.howso.com).

### Externalized Postgres Databases

If you choose not to use the built in Postgres database service of the Howso Platform, there are additional database setup steps that are required on your
externalized database.

#### LTREE Extension
The Howso Platform relies on the [Postgres ltree extension](https://www.postgresql.org/docs/current/ltree.html) to operate. Depending on the privileges you assigned to your database user, the `ltree` extension may need to be enabled manually.

On the database you created run the following SQL statement:
```sql
CREATE EXTENSION IF NOT EXISTS ltree;
```


### SSL CERTIFICATE_VERIFY_FAILED

If the verification script shows the following errors, you may need to [Trust the Certs](#trust-the-certs) or [Disable SSL Verification](#disable-ssl-verification) before proceeding.

```text
WARNING:urllib3.connectionpool:Retrying (Retry(total=2, connect=None, read=None, redirect=None, status=None)) after connection broken by
'SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1006)'))':
/oauth/token/
```

### Worker pods start but immediately crash

If you are running air-gapped installation examples on Mac Silicon - the verification script will attempt to create worker pods, but the amd64 images (from the air-gap image bundle) will not run correctly on the arm64 architecture (even using Rosetta emulation).  Online installation examples should download the correct image for the architecture.


## Quick Start

### Basic Helm Install

For examples that built off of a basic Helm install, the instructions for the [basic Helm install](../helm-basic/README.md) are combined below.

```sh
# prerequisites TLDR
# helm registry login registry.how.so --username your_email@example.com --password your_license_id
# add local.howso.com pypi|api|www|management.local.howso.com to /etc/hosts
# Install the [linkerd cli](https://linkerd.io/2/getting-started/) and the certificate tool [step](https://smallstep.com/docs/step-cli/).
# Setup the Kubernetes cluster
k3d cluster create --config prereqs/k3d-single-node.yaml
kubectl -n kube-system wait --for=condition=ready --timeout=180s pod -l k8s-app=metrics-server
kubectl create namespace howso
# Create datastore secrets
kubectl create secret generic platform-minio --from-literal=rootPassword="$(openssl rand -base64 20)" --from-literal=rootUser="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
kubectl create secret generic platform-postgres-postgresql --from-literal=postgres-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
kubectl create secret generic platform-redis --from-literal=redis-password="$(openssl rand -base64 20)" --dry-run=client -o yaml | kubectl -n howso apply -f -
# Install component charts
helm install platform-minio oci://registry.how.so/howso-platform/stable/minio --namespace howso --values helm-basic/manifests/minio.yaml --wait
helm install platform-nats oci://registry.how.so/howso-platform/stable/nats --namespace howso --values helm-basic/manifests/nats.yaml --wait
helm install platform-postgres oci://registry.how.so/howso-platform/stable/postgresql --namespace howso --values helm-basic/manifests/postgres.yaml --wait
helm install platform-redis oci://registry.how.so/howso-platform/stable/redis --namespace howso --values helm-basic/manifests/redis.yaml --wait
helm install howso-platform oci://registry.how.so/howso-platform/stable/howso-platform --namespace howso --values helm-basic/manifests/howso-platform.yaml --wait --timeout 20m
```