#!/bin/bash

# ============================================================
# AWS Terraform Backend Resources Script
# Creates and destroys:
#   - S3 Bucket for Terraform State
#   - Bucket Versioning
#   - Server-Side Encryption
#   - DynamoDB Table for Terraform Locking
#
# Usage:
#   ./terraform_backend.sh create
#   ./terraform_backend.sh destroy
#
# Requirements:
#   - AWS CLI installed
#   - AWS credentials configured (aws configure)
#   - Proper IAM permissions
# ============================================================
export AWS_PAGER=""
set -e

# -----------------------------
# Variables
# -----------------------------
BUCKET_NAME="proj-terraform-state-bucket-2026"
DYNAMODB_TABLE="tf-state-lock"
REGION="eu-west-1"   # Change if needed
PROFILE="default"

# -----------------------------
# Functions
# -----------------------------

create_resources() {
    echo "Creating S3 bucket: $BUCKET_NAME"

    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --create-bucket-configuration LocationConstraint="$REGION"

    echo "Enabling bucket versioning..."

    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --versioning-configuration Status=Enabled

    echo "Creating DynamoDB table: $DYNAMODB_TABLE"

    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions \
            AttributeName=LockID,AttributeType=S \
        --key-schema \
            AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --tags Key=Name,Value=tf-lock \
        --region "$REGION" \
        --profile "$PROFILE"

    echo "Resources created successfully."
}

destroy_resources() {
    echo "Deleting DynamoDB table: $DYNAMODB_TABLE"

    aws dynamodb delete-table \
        --table-name "$DYNAMODB_TABLE" \
        --profile "$PROFILE" \
        --region "$REGION" || true

    echo "Emptying S3 bucket before deletion..."

    aws s3 rm "s3://$BUCKET_NAME" \
        --recursive || true

    echo "Deleting all object versions and delete markers..."

# Delete object versions
aws s3api delete-objects \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --delete "$(aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
        --output=json)" \
    || true

# Delete delete markers
aws s3api delete-objects \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --delete "$(aws s3api list-object-versions \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --profile "$PROFILE" \
        --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
        --output=json)" \
    || true

    echo "Deleting S3 bucket: $BUCKET_NAME"

    aws s3api delete-bucket \
        --bucket "$BUCKET_NAME" \
        --profile "$PROFILE" \
        --region "$REGION"

    echo "Resources destroyed successfully."
}

# -----------------------------
# Main Logic
# -----------------------------

case "$1" in
    create)
        create_resources
        ;;
    destroy)
        destroy_resources
        ;;
    *)
        echo "Usage: $0 {create|destroy}"
        exit 1
        ;;
esac