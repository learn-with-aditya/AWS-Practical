#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:=ap-south-1}"
: "${TABLE_NAME:=StudentsLab}"
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=student_id,AttributeType=S \
  --key-schema AttributeName=student_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"
aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
aws dynamodb describe-table --table-name "$TABLE_NAME" \
  --query 'Table.{Name:TableName,Status:TableStatus}' --output table --region "$AWS_REGION"
