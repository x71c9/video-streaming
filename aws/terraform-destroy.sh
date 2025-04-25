#!/bin/bash

source "$(dirname "$0")/shared/parse.sh"

# Prompt user before terraform destroy
echo "Note: If there are files in the S3 bucket, Terraform will not be able to delete the bucket."
read -r -p "Do you want to delete all files in the S3 bucket before destroy? [Y/n] " answer
answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

if [[ "$answer" =~ ^(y|yes|)$ ]]; then
  echo "Emptying the S3 bucket..."
  # Replace this with the actual bucket name or fetch it dynamically
  BUCKET_NAME=$(terraform output -raw stream_bucket_name 2>/dev/null)

  if [ -z "$BUCKET_NAME" ]; then
    echo "Error: Could not determine bucket name from terraform output."
    exit 1
  fi

  aws s3 rm "s3://${BUCKET_NAME}" --recursive

else
  echo "Skipping S3 bucket deletion."
fi

echo "Running Terraform Destroy..."
if [ "$ASSUME_YES" = true ]; then
  terraform destroy -var-file="config/environment.tfvars" -auto-approve
else
  terraform destroy -var-file="config/environment.tfvars"
fi
