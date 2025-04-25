#!/bin/bash

source "$(dirname "$0")/shared/parse.sh"

echo "Running Terraform Destroy..."
if [ "$ASSUME_YES" = true ]; then
  terraform destroy -var-file="config/environment.tfvars" -auto-approve
else
  terraform destroy -var-file="config/environment.tfvars"
fi
