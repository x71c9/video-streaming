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
      ;;
  esac
done

./terraform-init.sh

