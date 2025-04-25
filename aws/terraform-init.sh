#!/bin/bash

echo "Running Terraform init..."
terraform init -backend-config=./config/backend.conf -reconfigure
