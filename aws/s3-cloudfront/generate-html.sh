#!/bin/bash

# Get the CloudFront URL from Terraform
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url)

# Check if the URL was retrieved
if [ -z "$CLOUDFRONT_URL" ]; then
  echo "Error: Could not retrieve CloudFront URL from Terraform."
  exit 1
fi

# Replace the placeholder in the template and output to index.html
sed "s|{{CLOUDFRONT_URL}}|${CLOUDFRONT_URL}|g" template.html > index.html

echo "index.html has been generated with CloudFront URL: https://${CLOUDFRONT_URL}/stream/index.m3u8"

