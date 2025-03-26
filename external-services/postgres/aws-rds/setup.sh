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

# Use default CIDR if not provided
if [ -z "$CLUSTER_CIDR" ]; then
    CLUSTER_CIDR="10.0.0.0/16"
    echo "Using default CIDR: $CLUSTER_CIDR"
fi

# Look up the security group in the given VPC
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=platform-postgres-sg Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# If it doesn't exist (describe returns "None" or empty), create it
if [ "$SECURITY_GROUP_ID" = "None" ] || [ -z "$SECURITY_GROUP_ID" ]; then
  echo "Creating security group..."
  SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name platform-postgres-sg \
    --description "Security group for platform PostgreSQL RDS" \
    --vpc-id "$VPC_ID" \
    --output text --query 'GroupId')
else
  echo "Security group already exists: $SECURITY_GROUP_ID"
fi

# Check for inbound rules for PostgreSQL
existing_cluster_rule_postgres=$(aws ec2 describe-security-groups \
  --group-names platform-postgres-sg \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432` && ToPort==`5432` && IpProtocol==`tcp`].IpRanges[?CidrIp=="'"$CLUSTER_CIDR"'"]' \
  --output text)

# Add inbound rules for PostgreSQL if not present
if [ -z "$existing_cluster_rule_postgres" ]; then
  echo "Adding cluster ingress rule for CIDR $CLUSTER_CIDR..."
  aws ec2 authorize-security-group-ingress \
    --group-name platform-postgres-sg \
    --protocol tcp \
    --port 5432 \
    --cidr "$CLUSTER_CIDR"
else
  echo "Cluster ingress rule for CIDR $CLUSTER_CIDR already exists."
fi

existing_cluster_rule_user_ip=$(aws ec2 describe-security-groups \
  --group-names platform-postgres-sg \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432` && ToPort==`5432` && IpProtocol==`tcp`].Ipv6Ranges[?CidrIpv6=="'"$USER_IP"'"]' \
  --output text)

if [ -z "$existing_cluster_rule_user_ip" ]; then
  # Check if it's an IPv4 address (simple regex)
  if [[ "$USER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Detected IPv4 address: $USER_IP"
    aws ec2 authorize-security-group-ingress \
      --group-name platform-postgres-sg \
      --protocol tcp \
      --port 5432 \
      --cidr "${USER_IP}/32"
  elif [[ "$USER_IP" =~ : ]]; then
    # A basic check for IPv6 by looking for a colon
    echo "Detected IPv6 address: $USER_IP"
    aws ec2 authorize-security-group-ingress \
      --group-name platform-postgres-sg \
      --ip-permissions IpProtocol=tcp,FromPort=5432,ToPort=5432,Ipv6Ranges=[{CidrIpv6=$USER_IP/128}]
  else
    echo "Error: Invalid IP address format."
    exit 1
  fi
else
  echo "Ingress rule for $USER_IP already exists."
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
