#!/bin/bash
# Script to apply Terraform with multi-region configuration

# Set working directory
cd "$(dirname "$0")" || exit 1
echo "Working directory: $(pwd)"

echo "====================================================="
echo "  AMAZON CONNECT ANALYTICS WITH MULTI-REGION SETUP"
echo "====================================================="
echo "This script will deploy the Amazon Connect Analytics Pipeline with:"
echo "- Amazon Connect and most resources in eu-west-2 (London)"
echo "- Amazon Timestream in eu-west-1 (Ireland) where it's supported"
echo "====================================================="
echo

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create new state file
echo "Running Terraform plan..."
terraform plan -out=tf.plan

# Ask for confirmation
echo
echo "Ready to deploy the multi-region configuration."
echo "Continue with apply? (y/n)"
read -r answer
if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
  echo "Applying Terraform configuration..."
  terraform apply tf.plan
  
  if [ $? -eq 0 ]; then
    echo
    echo "====================================================="
    echo "  DEPLOYMENT SUCCESSFUL"
    echo "====================================================="
    echo "Your multi-region setup has been deployed with:"
    echo "- Amazon Connect in eu-west-2 (London)"
    echo "- Timestream in eu-west-1 (Ireland)"
    echo
    echo "Grafana has been configured to access both regions."
    echo "See the outputs above for connection details."
    echo "====================================================="
  else
    echo "Terraform apply failed. Please check the errors above."
  fi
else
  echo "Deployment cancelled."
fi