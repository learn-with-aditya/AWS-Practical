#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:=ap-south-1}"
: "${TABLE_NAME:=StudentsLab}"
echo "About to DELETE DynamoDB table: $TABLE_NAME in $AWS_REGION"
read -r -p "Type DELETE to continue: " answer
[[ "$answer" == "DELETE" ]] || { echo "Cancelled."; exit 1; }
aws dynamodb delete-table --table-name "$TABLE_NAME" --region "$AWS_REGION"
aws dynamodb wait table-not-exists --table-name "$TABLE_NAME" --region "$AWS_REGION"
echo "Table deleted."
