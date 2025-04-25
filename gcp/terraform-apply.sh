#!/bin/bash

set -e

source "$(dirname "$0")/shared/parse.sh"

echo "Running Terraform Apply..."
if [ "$ASSUME_YES" = true ]; then
  terraform apply -var-file="config/environment.tfvars" -auto-approve
else
  terraform apply -var-file="config/environment.tfvars"
fi
