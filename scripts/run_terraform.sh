#!/bin/bash
# Script to run Terraform with proper initialization and apply

# Set working directory
cd "$(dirname "$0")" || exit 1
echo "Working directory: $(pwd)"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Check for existing state
if [ -f "terraform.tfstate" ]; then
  echo "Existing terraform.tfstate found, backing it up..."
  mv terraform.tfstate terraform.tfstate.backup.$(date +%s)
fi

# Run terraform plan
echo "Running terraform plan..."
terraform plan -out=tf.plan

# If plan succeeded, ask before applying
if [ $? -eq 0 ]; then
  echo ""
  echo "Plan generated successfully. Apply changes? (y/n)"
  read -r answer
  if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    echo "Applying Terraform plan..."
    terraform apply tf.plan
    echo ""
    echo "Terraform apply complete. Check outputs above."
  else
    echo "Terraform apply cancelled."
  fi
else
  echo "Terraform plan failed. Please check errors above."
fi