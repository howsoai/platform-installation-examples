#!/bin/bash

# Note: This script uses the AWS region configured in your AWS CLI configuration
#       (via AWS_DEFAULT_REGION environment variable or ~/.aws/config)
#       Make sure you have configured the correct region before running this script.

# Exit on error
set -e

SG_NAME='platform-postgres-sg'

# Check required environment variables
if [ -z "$VPC_ID" ]; then
    echo "Error: VPC_ID environment variable is required"
    exit 1
fi

if [ -z "$SUBNET_IDS" ]; then
    echo "Error: SUBNET_IDS environment variable is required"
    exit 1
fi

# Look up the security group in the given VPC
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values="$SG_NAME" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# If it doesn't exist (describe returns "None" or empty), create it
if [ "$SECURITY_GROUP_ID" = "None" ] || [ -z "$SECURITY_GROUP_ID" ]; then
  echo "Creating security group..."
  SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Security group for platform PostgreSQL RDS" \
    --vpc-id "$VPC_ID" \
    --output text --query 'GroupId')
else
  echo "Security group already exists: $SECURITY_GROUP_ID"
fi

# Check for inbound rules for PostgreSQL
existing_cluster_rule_postgres=$(aws ec2 describe-security-groups \
  --group-names "$SG_NAME" \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432` && ToPort==`5432` && IpProtocol==`tcp`].IpRanges' \
  --output text | grep 0.0.0.0/0)

# Add inbound rules for PostgreSQL if not present
if [ -z "$existing_cluster_rule_postgres" ]; then
  echo "Adding cluster ingress rule for 0.0.0.0/0"
  aws ec2 authorize-security-group-ingress \
    --group-name "$SG_NAME" \
    --protocol tcp \
    --port 5432 \
    --cidr "0.0.0.0/0"
else
  echo "Cluster ingress rule for CIDR $CLUSTER_CIDR already exists."
fi

# Create subnet group
echo "Creating subnet group..."
aws rds create-db-subnet-group \
  --db-subnet-group-name platform-postgres-subnet-group \
  --db-subnet-group-description "Subnet group for platform PostgreSQL" \
  --subnet-ids $SUBNET_IDS

# Generate random password (using only allowed characters)
echo "Generating database password..."
DB_PASSWORD=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 16)

# Create RDS instance
echo "Creating RDS instance..."
aws rds create-db-instance \
  --db-instance-identifier platform-postgres \
  --engine postgres \
  --engine-version 14 \
  --db-instance-class db.t3.micro \
  --allocated-storage 20 \
  --db-name platform \
  --master-username platform_admin \
  --master-user-password $DB_PASSWORD \
  --vpc-security-group-ids $SECURITY_GROUP_ID \
  --db-subnet-group-name platform-postgres-subnet-group \
  --publicly-accessible

echo "RDS instance creation started. This may take several minutes..."
echo "You can check the status with: aws rds describe-db-instances --db-instance-identifier platform-postgres"

# Wait for the instance to be available
echo "Waiting for instance to be available..."
aws rds wait db-instance-available --db-instance-identifier platform-postgres

# Get the endpoint
ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier platform-postgres \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "RDS instance created successfully!"
echo
echo "Environment variables for values files:"
echo "export PGHOST=\"$ENDPOINT\""
echo "export PGPORT=\"5432\""
echo "export PGDATABASE=\"platform\""
echo "export PGUSER=\"platform_admin\""
echo "export PGPASSWORD=\"$DB_PASSWORD\""
echo
