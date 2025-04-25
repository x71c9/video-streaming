#!/bin/bash

# Get the CloudFront URL from Terraform
STREAM_BUCKET_NAME=$(terraform output -raw stream_bucket_name)

# Check if the URL was retrieved
if [ -z "$STREAM_BUCKET_NAME" ]; then
  echo "Error: Could not retrieve Bucket Name from Terraform."
  exit 1
fi

STREAM_URL="https://storage.googleapis.com/${STREAM_BUCKET_NAME}/streaming/index.m3u8"

# Replace the placeholder in the template and output to index.html
sed "s|{{STREAM_URL}}|${STREAM_URL}|g" template.html > index.html

echo "index.html has been generated with Stream URL: ${STREAM_URL}"

