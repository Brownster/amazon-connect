#!/bin/bash
# Script to apply Terraform configuration with a new state file and unique resource names

# Set working directory
cd "$(dirname "$0")" || exit 1
echo "Changing to project directory: $(pwd)"

# Generate a unique suffix for resource names
SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
echo "Using unique suffix for resources: $SUFFIX"

# Execute terraform apply with a new state file and variable overrides
terraform apply \
  -state="terraform.tfstate.new" \
  -var="project_name=connect-analytics-${SUFFIX}" \
  -var="instance_alias=thebrowns-${SUFFIX}" \
  -var="aws_region=eu-west-2"

echo
echo "If successful, the new state is in terraform.tfstate.new"
echo "To use this state file for future operations, rename it to terraform.tfstate:"
echo "mv terraform.tfstate.new terraform.tfstate"