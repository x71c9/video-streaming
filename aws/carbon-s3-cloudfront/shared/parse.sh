#!/bin/bash

# Parse parameters
ASSUME_YES=false
for arg in "$@"; do
  case $arg in
    --assume-yes)
      ASSUME_YES=true
      shift
      ;;
    *)
      ENV=$arg
      ;;
  esac
done

ENV_DIR=./environments/$ENV

if [ -z "$ENV" ]; then
  echo "You should specify the target environment as the first parameter."
  echo "It should be a directory under ./environments."
  echo
  echo "Example: $0 dev"
  exit 1
fi

if [ ! -d "$ENV_DIR" ]; then
  echo "Error: environment directory '${ENV_DIR}' not found."
  exit 1
fi

echo "Before Run Terraform init..."
bash ./terraform-init.sh ${ENV}

