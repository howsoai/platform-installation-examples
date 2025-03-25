#!/bin/bash

# Note: This script uses the AWS region configured in your AWS CLI configuration
#       (via AWS_DEFAULT_REGION environment variable or ~/.aws/config)
#       Make sure you have configured the correct region before running this script.

# Exit on error
set -e

echo "Starting cleanup of RDS resources..."

# Check and delete RDS instance if it exists
echo "Checking for RDS instance..."
if aws rds describe-db-instances --db-instance-identifier platform-postgres --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null | grep -q "available"; then
    echo "Deleting RDS instance..."
    aws rds delete-db-instance \
        --db-instance-identifier platform-postgres \
        --skip-final-snapshot \
        --delete-automated-backups

    echo "Waiting for RDS instance to be deleted..."
    aws rds wait db-instance-deleted --db-instance-identifier platform-postgres
else
    echo "No RDS instance found to delete"
fi

# Check and delete subnet group if it exists
echo "Checking for subnet group..."
if aws rds describe-db-subnet-groups --db-subnet-group-name platform-postgres-subnet-group --query 'DBSubnetGroups[0].DBSubnetGroupName' --output text 2>/dev/null | grep -q "platform-postgres-subnet-group"; then
    echo "Deleting subnet group..."
    aws rds delete-db-subnet-group \
        --db-subnet-group-name platform-postgres-subnet-group
else
    echo "No subnet group found to delete"
fi

# Check and delete security group if it exists
echo "Checking for security group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=platform-postgres-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null)

if [ "$SG_ID" != "None" ] && [ ! -z "$SG_ID" ]; then
    echo "Deleting security group..."
    aws ec2 delete-security-group --group-name platform-postgres-sg
else
    echo "No security group found to delete"
fi

echo "Cleanup completed successfully!"
echo
echo "You may want to unset these environment variables:"
echo "unset PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD"