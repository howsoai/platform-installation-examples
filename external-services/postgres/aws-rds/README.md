# AWS RDS PostgreSQL for Howso Platform

## Overview

This guide provides instructions for configuring the Howso Platform's PostgreSQL database to use an external Amazon RDS instance.  This allows the use of AWS's managed PostgreSQL service instead of the in-cluster PostgreSQL deployment.

> Note: This guide focuses on an external PostgreSQL setup that is easy to replicate, as it is small and accessible from the internet.  It is not intended to be a production-ready PostgreSQL setup for the Howso Platform, which will, at the least, require a larger instance type and more locked-down network configuration.

> Note: This guide assumes a fresh installation of the Howso Platform. If you need to migrate an existing installation to RDS, see the [Migration](#migration) section at the end of this guide.

## Prerequisites

- [General prerequisites](../prereqs/README.md)
- [Helm Online Installation for Howso Platform](../helm-basic/README.md)
- [AWS CLI installed](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
- AWS account with appropriate permissions
- VPC and subnet information for a region with internet access.

## Setup

### 1. Create RDS Instance

You can either use the provided setup script to create an RDS instance, or [set up the RDS instance manually](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_GettingStarted.CreatingConnecting.PostgreSQL.html) through the AWS Console or CLI.

If using the setup script:

```bash
# Set required environment variables
```bash
# Set required environment variables
export VPC_ID="your-vpc-id"
export CLUSTER_CIDR="your-cluster-cidr"
export SUBNET_IDS="subnet-id1,subnet-id2"

# Run setup script
cd external-services/postgres/aws-rds
./setup.sh
```

### 2. Verify Required Extensions

The Howso Platform relies on the [Postgres ltree extension](https://www.postgresql.org/docs/current/ltree.html) to operate. This extension is typically pre-installed on AWS RDS PostgreSQL instances. You can verify it's available by connecting to your RDS instance and running:

```bash
# Set PostgreSQL connection environment variables
export PGHOST="your-rds-endpoint.region.rds.amazonaws.com"
export PGPORT="5432"
export PGUSER="platform_admin"
export PGDATABASE="platform"
export PGPASSWORD="your-secure-password"

# Verify the extension
psql -c "CREATE EXTENSION IF NOT EXISTS ltree;"
```

If you see "NOTICE: extension 'ltree' already exists, skipping", then you're all set. If the extension is not available, it can be enabled through the AWS RDS Console under the database's Configuration tab in the Parameter groups section.

### 3. Configure Howso Platform

Initially we will setup a minimal TLS connection to the RDS instance, and then ratchet up the security to include server certificate verification, and finally to include client certificate verification (mutual TLS).

#### Basic SSL Configuration

The `require` SSL mode ensures that all traffic between the Howso Platform and RDS is encrypted, but it does not verify the server's identity.

The [basic values file](./values/basic.yaml) configures the platform to connect to RDS with basic SSL encryption:

```yaml
datastores:
  postgres:
    ums:
      host: your-rds-endpoint.region.rds.amazonaws.com
      port: 5432
      name: platform
      user: platform_admin
      password: your-secure-password
      sslmode: require
      serverVerificationCustomCertChain: false
      clientVerification: false
```

Apply the configuration and verify the pods restart successfully:

```bash
# Apply the new configuration
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values values/basic.yaml

# Wait for pods to restart and check their status
kubectl get pods -n howso -w

# Verify all pods are running
kubectl get pods -n howso
```

Since this is a fresh installation, you'll need to login and setup credentials for the platform using the [instructions here](../common/README.md#login-to-the-howso-platform).

#### Verify-CA SSL Configuration (sslmode: verify-ca)

The `verify-ca` SSL mode checks the RDS server's certificate against a trusted certificate authority (CA), protecting against man-in-the-middle attacks.  The Howso Platform will need access to the RDS CA certificate in order to verify the RDS server's certificate, this is done by creating a Kubernetes secret containing the RDS CA certificate.

- Download the RDS certificate bundle:
```bash
# Create certificates directory
mkdir -p certs/postgres

# Download RDS certificate bundle
curl -o certs/postgres/rds-ca-2019-root.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem
```

- Create the certificate chain secret:
```bash
kubectl create secret generic platform-postgres-certchain \
    --from-file=ca.crt=certs/postgres/rds-ca-2019-root.pem
```

- The [verify-ca values file](./values/verify-ca.yaml) configures the platform to verify the RDS server certificate. The key changes from the basic configuration are:
- Setting `sslmode: verify-ca` to enable server certificate verification
- Enabling `serverVerificationCustomCertChain: true` to use our custom certificate chain
- Specifying `serverCertChainSecretName: platform-postgres-certchain` to reference the RDS certificate bundle

Apply the configuration and verify the pods restart successfully:

```bash
# Apply the new configuration
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values values/verify-ca.yaml

# Wait for pods to restart and check their status
kubectl get pods -n howso -w

# Verify all pods are running
kubectl get pods -n howso
```

#### Client Certificate Configuration (sslmode: verify-full)

The `verify-full` SSL mode requires both server and client certificate verification (mutual TLS). This configuration requires significant additional setup on the RDS which is beyond the scope of this guide.

> Note: Setting up client certificates on RDS requires:
> - Creating a custom parameter group for RDS
> - Configuring the parameter group to trust your client certificate CA
> - Modifying the RDS instance to use the custom parameter group
> - Restarting the RDS instance
> 
> For complete details on the RDS configuration, see the [AWS documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html).

The Kubernetes configuration for client certificates is shown below, but note that this will only work after the RDS instance has been properly configured to trust your client certificate CA:

- Generate client certificate (using the RDS trusted CA):
```bash
# Create certificates directory if not exists
mkdir -p certs/postgres

# Generate private key
openssl genrsa -out certs/postgres/client.key 4096

# Generate certificate signing request (CSR)
openssl req -new -key certs/postgres/client.key \
    -out certs/postgres/client.csr \
    -subj "/CN=platform-admin"

# Sign the CSR with your trusted CA
openssl x509 -req -in certs/postgres/client.csr \
    -CA /path/to/your/ca.crt \
    -CAkey /path/to/your/ca.key \
    -CAcreateserial \
    -out certs/postgres/client.crt \
    -days 365
```

- Create the client certificate secret:
```bash
kubectl create secret generic platform-postgres-client-cert \
    --from-file=tls.crt=certs/postgres/client.crt \
    --from-file=tls.key=certs/postgres/client.key
```

- The [verify-full values file](./values/verify-full.yaml) configures the platform to use client certificates:

```yaml
# Key changes from verify-full configuration:
datastores:
  postgres:
    ums:
      sslmode: verify-full
      clientVerification: true
      clientCertSecretName: platform-postgres-client-cert
```

> Note: The verify-full configuration requires that the Howso Platform trust the RDS CA certificate, so make sure to [follow the steps above](#verify-ca-ssl-configuration-sslmode-verify-ca) to create the RDS CA certificate secret.

Apply the configuration and verify the pods restart successfully:

```bash
# Apply the new configuration
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values values/verify-full.yaml

# Wait for pods to restart and check their status
kubectl get pods -n howso -w

# Verify all pods are running
kubectl get pods -n howso
```

## Migration

If you have an existing Howso Platform installation and need to migrate your data to RDS, follow these steps:

- First, complete the RDS setup and configuration steps above (Create RDS Instance, Verify Required Extensions, and Configure Howso Platform)
- Once the RDS instance is ready and configured, proceed with the data migration:

```bash
# Get existing database credentials
kubectl get secret platform-postgres-postgresql -o jsonpath='{.data.postgres-password}' | base64 -d
```

```bash
# Backup database
kubectl exec -it $(kubectl get pod -l app=postgresql -o jsonpath='{.items[0].metadata.name}') -- \
  pg_dump -U postgres platform > platform_backup.sql
```

```bash
# Restore to RDS (replace with your RDS endpoint)
psql -h your-rds-endpoint.region.rds.amazonaws.com -U platform_admin -d platform < platform_backup.sql
```

```bash
# Apply new values
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values values.yaml
```

## Troubleshooting

If you encounter connection issues after applying the configuration:

- Check the logs of the SMS and UMS pods, as they will show detailed connection information:
```bash
# Check SMS logs
kubectl logs -n howso -l app=sms

# Check UMS logs
kubectl logs -n howso -l app=ums
```

## Cleanup

To remove the AWS RDS resources created during testing, a cleanup script is provided:

> Note: This script will delete AWS resources, please check the script before running it.

```bash
./cleanup.sh
```

