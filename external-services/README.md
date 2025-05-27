# External Datastores for Howso Platform

This section contains guides for externalizing various services used by the Howso Platform.  Whilst the guides show specific back-end providers, the general principles can be applied to other providers.

## Available Guides

### PostgreSQL
- [AWS RDS PostgreSQL](postgres/aws-rds/README.md) - Guide for migrating PostgreSQL to Amazon RDS

### S3 Compatible Object Store (Coming Soon)

### Note on Redis and NATS
It is not recommended to externalize either the Redis cache or the NATS messaging system.

For Redis, externalization is unnecessary for system recovery purposes, and maintaining a local, high-speed agent cache is critical for optimal Howso Platform performance.

NATS similarly should remain internal - its persistence is only required for in-flight trainees, and the platform relies on NATS' speed and reliability for message delivery.

Both Redis and NATS can be fully configured through the Howso Helm chart if specific customization is needed. See [Redis licensing update](../../redis-license-update.md) for important information about Redis versions and alternatives.
