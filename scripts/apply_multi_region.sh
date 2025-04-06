#!/bin/bash
# Script to apply Terraform configuration with multi-region setup for Timestream

cd "$(dirname "$0")" || exit 1
echo "Working directory: $(pwd)"

echo "====================================================="
echo "  APPLYING MULTI-REGION CONFIGURATIONS"
echo "====================================================="
echo "This script will apply the IAM policy changes for Timestream access"
echo

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Target only the new IAM policy for Timestream
echo "Planning targeted Terraform apply..."
terraform plan -target=aws_iam_role_policy.grafana_timestream

# Ask for confirmation
echo
echo "Ready to apply the Timestream IAM policies."
echo "Continue with apply? (y/n)"
read -r answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
  echo "Applying Terraform configuration..."
  terraform apply -target=aws_iam_role_policy.grafana_timestream -auto-approve
  
  if [ $? -eq 0 ]; then
    echo
    echo "====================================================="
    echo "  MULTI-REGION CONFIGURATION SUCCESSFUL"
    echo "====================================================="
    echo "Timestream permissions have been successfully applied."
    echo "Grafana now has access to Timestream in eu-west-1."
    echo 
    echo "To verify the configuration:"
    echo "1. SSH into the Grafana instance"
    echo "2. Access the Grafana UI"
    echo "3. Check the Timestream data source configuration"
    echo "====================================================="
  else
    echo "Terraform apply failed. Please check the errors above."
  fi
else
  echo "Deployment cancelled."
fi