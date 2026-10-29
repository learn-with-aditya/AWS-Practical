#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:=ap-south-1}"
: "${TABLE_NAME:=StudentsLab}"

echo 'CREATE: insert STU001'
aws dynamodb put-item --table-name "$TABLE_NAME" \
  --item '{"student_id":{"S":"STU001"},"name":{"S":"Aarav Sharma"},"course":{"S":"AWS"},"score":{"N":"85"}}' \
  --region "$AWS_REGION"

echo 'READ: get STU001'
aws dynamodb get-item --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"STU001"}}' --region "$AWS_REGION"

echo 'UPDATE: change score and add city'
aws dynamodb update-item --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"STU001"}}' \
  --update-expression 'SET #score = :score, city = :city' \
  --expression-attribute-names '{"#score":"score"}' \
  --expression-attribute-values '{":score":{"N":"95"},":city":{"S":"Mumbai"}}' \
  --return-values ALL_NEW --region "$AWS_REGION"

echo 'DELETE: remove STU001'
aws dynamodb delete-item --table-name "$TABLE_NAME" \
  --key '{"student_id":{"S":"STU001"}}' \
  --return-values ALL_OLD --region "$AWS_REGION"
