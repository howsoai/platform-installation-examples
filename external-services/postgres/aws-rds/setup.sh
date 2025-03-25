#!/bin/bash

# Note: This script uses the AWS region configured in your AWS CLI configuration
#       (via AWS_DEFAULT_REGION environment variable or ~/.aws/config)
#       Make sure you have configured the correct region before running this script.

# Exit on error
set -e

# Check required environment variables
if [ -z "$VPC_ID" ]; then
    echo "Error: VPC_ID environment variable is required"
    exit 1
fi

if [ -z "$CLUSTER_CIDR" ]; then
    echo "Error: CLUSTER_CIDR environment variable is required"
    exit 1
fi

if [ -z "$SUBNET_IDS" ]; then
    echo "Error: SUBNET_IDS environment variable is required"
    exit 1
fi

# Get the user's public IP
echo "Getting your public IP address..."
USER_IP=$(curl -s ifconfig.me)
if [ -z "$USER_IP" ]; then
    echo "Error: Could not determine your public IP address"
    exit 1
fi
echo "Your public IP: $USER_IP"

# Create security group
echo "Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name platform-postgres-sg \
  --description "Security group for platform PostgreSQL RDS" \
  --vpc-id $VPC_ID \
  --output text --query 'GroupId')

# Add inbound rules for PostgreSQL
echo "Adding inbound rules for PostgreSQL..."
# Allow access from the cluster
aws ec2 authorize-security-group-ingress \
  --group-name platform-postgres-sg \
  --protocol tcp \
  --port 5432 \
  --cidr $CLUSTER_CIDR

# Allow access from the user's IP
echo "Adding your IP ($USER_IP) to security group..."
aws ec2 authorize-security-group-ingress \
  --group-name platform-postgres-sg \
  --protocol tcp \
  --port 5432 \
  --cidr "$USER_IP/32"

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