#!/bin/bash
# Script to force creation of Timestream resources

cd "$(dirname "$0")" || exit 1
echo "Creating a standalone Timestream database in eu-west-1..."

# Create a temporary file for direct Timestream deployment
cat > timestream_direct.tf <<EOF
provider "aws" {
  alias  = "timestream" 
  region = "eu-west-1"
}

resource "aws_timestreamwrite_database" "connect_db_direct" {
  provider      = aws.timestream
  database_name = "connect-analytics-direct"
  
  tags = {
    Name = "Connect Analytics Timestream Database (Direct)"
  }
}

output "timestream_database_direct" {
  value = aws_timestreamwrite_database.connect_db_direct.database_name
}
EOF

# Initialize and apply
terraform init
echo "Planning Timestream direct deployment..."
terraform plan -target=aws_timestreamwrite_database.connect_db_direct
echo "Apply this plan? (y/n)"
read -r CONFIRM

if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
  terraform apply -target=aws_timestreamwrite_database.connect_db_direct -auto-approve
  
  # Check result
  echo "Checking created database via terraform output:"
  terraform output timestream_database_direct
  
  echo "Checking created database via AWS CLI:"
  aws timestream-write list-databases --region eu-west-1
else
  echo "Deployment cancelled"
fi