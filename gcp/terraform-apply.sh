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
echo "  - BUCKET_NAME"
echo "  - REGION"
echo "  - ALERT_EMAIL"
echo "  - MAILGUN_API_KEY"
echo "  - MAILGUN_DOMAIN"
echo
echo "Alternatively, you can get them manually with:"
echo
echo "  BUCKET_NAME=\$(terraform output -raw stream_bucket_name)"
echo "  REGION=\$(terraform output -raw region)"
echo "  ALERT_EMAIL=\$(terraform output -raw alert_email)"
echo "  MAILGUN_API_KEY="
echo "  MAILGUN_DOMAIN="
echo

