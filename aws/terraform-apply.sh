#!/bin/bash

set -e

source "$(dirname "$0")/shared/parse.sh"

echo "Running Terraform Apply..."
if [ "$ASSUME_YES" = true ]; then
  terraform apply -var-file="config/environment.tfvars" -auto-approve
else
  terraform apply -var-file="config/environment.tfvars"
fi

echo "------------------------------------------------------------------------"
echo
echo "Now you can generate a .env file needed for the scripts in ./camerahost"
echo "by running:"
echo
echo -e "\033[1m  bash generate-dotenv.sh\033[0m"
echo
echo "The .env file will include:"
echo "  - AWS_ACCESS_KEY_ID"
echo "  - AWS_SECRET_ACCESS_KEY"
echo "  - BUCKET_NAME"
echo "  - REGION"
echo "  - ALERT_EMAIL"
echo
echo "Alternatively, you can get them manually with:"
echo
echo "  ACCESS_KEY_ID=\$(terraform output -raw s3_upload_aws_access_key_id)"
echo "  SECRET_ACCESS_KEY=\$(terraform output -raw s3_upload_aws_secret_access_key)"
echo "  BUCKET_NAME=\$(terraform output -raw bucket_name)"
echo "  REGION=\$(terraform output -raw region)"
echo "  ALERT_EMAIL=\$(terraform output -raw alert_email)"
echo

