#!/bin/bash
# Script to apply only the Timestream module in eu-west-1

# Set working directory
cd "$(dirname "$0")" || exit 1
echo "Working directory: $(pwd)"

echo "====================================================="
echo "  DEPLOYING TIMESTREAM RESOURCES IN EU-WEST-1"
echo "====================================================="
echo

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Target only the Timestream module
echo "Planning Timestream module deployment..."
terraform plan -target=module.timestream -out=tf.timestream.plan

# Ask for confirmation
echo
echo "Ready to deploy Timestream resources in eu-west-1."
echo "Continue with apply? (y/n)"
read -r answer
if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
  echo "Applying Timestream module..."
  terraform apply tf.timestream.plan
  
  if [ $? -eq 0 ]; then
    echo
    echo "====================================================="
    echo "  TIMESTREAM DEPLOYMENT SUCCESSFUL"
    echo "====================================================="
    echo "Timestream resources have been deployed in eu-west-1."
    echo
    echo "Next, deploy the Grafana module to connect to Timestream:"
    echo "terraform apply -target=module.grafana"
    echo "====================================================="
  else
    echo "Terraform apply failed. Please check the errors above."
  fi
else
  echo "Deployment cancelled."
fi