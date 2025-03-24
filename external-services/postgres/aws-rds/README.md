# AWS RDS PostgreSQL for Howso Platform

This guide provides instructions for migrating the Howso Platform's PostgreSQL database to Amazon RDS.

## Prerequisites

- AWS CLI installed and configured
- AWS account with appropriate permissions
- VPC and subnet information for your cluster
- Existing Howso Platform installation with in-cluster PostgreSQL

## Setup

### 1. Create RDS Instance

Use the provided setup script to create the RDS instance:

```bash
# Set required environment variables
export VPC_ID="your-vpc-id"
export CLUSTER_CIDR="your-cluster-cidr"
export SUBNET_IDS="subnet-id1,subnet-id2"

# Run setup script
./setup.sh
```

### 2. Configure Howso Platform

Create a values file for basic SSL connection:

```yaml
datastores:
  postgres:
    ums:
      host: ${DB_HOST}
      port: ${DB_PORT}
      name: ${DB_NAME}
      user: ${DB_USER}
      password: ${DB_PASSWORD}
      sslmode: require
      serverVerificationCustomCertChain: false
      clientVerification: false
```

## Migration

1. Backup existing database:
```bash
# Get existing database credentials
kubectl get secret platform-postgres-postgresql -o jsonpath='{.data.postgres-password}' | base64 -d

# Backup database
kubectl exec -it $(kubectl get pod -l app=postgresql -o jsonpath='{.items[0].metadata.name}') -- \
  pg_dump -U postgres platform > platform_backup.sql
```

2. Restore to RDS:
```bash
# Restore to RDS (replace with your RDS endpoint)
psql -h ${RDS_ENDPOINT} -U platform_admin -d platform < platform_backup.sql
```

3. Update platform configuration:
```bash
# Apply new values
helm upgrade howso-platform oci://registry.how.so/howso-platform/stable/howso-platform \
  --namespace howso \
  --values values.yaml
```

## Rollback

If issues occur during migration:

1. Revert platform configuration:
```bash
helm rollback howso-platform
```

2. Restore from backup if needed:
```bash
psql -h ${OLD_DB_HOST} -U postgres -d platform < platform_backup.sql
``` 