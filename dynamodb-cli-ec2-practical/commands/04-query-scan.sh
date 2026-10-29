#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:=ap-south-1}"
: "${TABLE_NAME:=StudentsLab}"

aws dynamodb query --table-name "$TABLE_NAME" \
  --key-condition-expression 'student_id = :id' \
  --expression-attribute-values '{":id":{"S":"STU001"}}' \
  --region "$AWS_REGION"

# Scan reads across the table. Use only on the small training table.
aws dynamodb scan --table-name "$TABLE_NAME" \
  --projection-expression 'student_id, course, #n' \
  --expression-attribute-names '{"#n":"name"}' \
  --region "$AWS_REGION"
