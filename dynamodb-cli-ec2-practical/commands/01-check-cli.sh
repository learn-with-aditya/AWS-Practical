#!/usr/bin/env bash
set -euo pipefail
aws --version
aws sts get-caller-identity
printf 'Region: %s\n' "${AWS_REGION:-ap-south-1}"
