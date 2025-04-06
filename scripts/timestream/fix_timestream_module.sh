#!/bin/bash
# Script to fix and apply Timestream module

cd "$(dirname "$0")" || exit 1
echo "Working on fixing Timestream module..."

# Create a direct database and tables for the Timestream module
SUFFIX=$(terraform output -raw connect_instance_id | cut -c1-8)
DB_NAME="connect-analytics-ts-${SUFFIX}"

# Create a clean Timestream configuration
cat > timestream_fixed.tf <<EOF
# Timestream Provider in eu-west-1
provider "aws" {
  alias  = "timestream_fixed"
  region = "eu-west-1"
}

# KMS Key for Timestream database encryption
resource "aws_kms_key" "timestream_key" {
  provider                = aws.timestream_fixed
  description             = "KMS Key for Timestream database ${DB_NAME}"
  key_usage               = "ENCRYPT_DECRYPT"
  is_enabled              = true
  enable_key_rotation     = true
  deletion_window_in_days = 7
  
  tags = {
    Name = "TimestreamKMSKey"
  }
}

# Timestream Database
resource "aws_timestreamwrite_database" "connect_analytics_db" {
  provider      = aws.timestream_fixed
  database_name = "${DB_NAME}"
  kms_key_id    = aws_kms_key.timestream_key.arn
  
  tags = {
    Name = "TimestreamDB"
  }
}

# Create essential tables
resource "aws_timestreamwrite_table" "agent_events" {
  provider      = aws.timestream_fixed
  database_name = aws_timestreamwrite_database.connect_analytics_db.database_name
  table_name    = "AgentEvents"
  
  retention_properties {
    memory_store_retention_period_in_hours = 24
    magnetic_store_retention_period_in_days = 30
  }
  
  tags = {
    Name = "AgentEvents"
  }
}

resource "aws_timestreamwrite_table" "contact_events" {
  provider      = aws.timestream_fixed
  database_name = aws_timestreamwrite_database.connect_analytics_db.database_name
  table_name    = "ContactEvents"
  
  retention_properties {
    memory_store_retention_period_in_hours = 24
    magnetic_store_retention_period_in_days = 30
  }
  
  tags = {
    Name = "ContactEvents"
  }
}

# Outputs for connecting with Grafana
output "timestream_fixed_database_name" {
  value = aws_timestreamwrite_database.connect_analytics_db.database_name
}

output "timestream_fixed_database_arn" {
  value = aws_timestreamwrite_database.connect_analytics_db.arn
}

output "timestream_fixed_kms_key_arn" {
  value = aws_kms_key.timestream_key.arn
}

output "timestream_fixed_tables" {
  value = {
    agent_events = aws_timestreamwrite_table.agent_events.table_name
    contact_events = aws_timestreamwrite_table.contact_events.table_name
  }
}
EOF

echo "Created timestream_fixed.tf configuration"
echo "Applying Timestream resources..."

# Apply the specific resources
terraform apply -target=aws_timestreamwrite_database.connect_analytics_db -target=aws_timestreamwrite_table.agent_events -target=aws_timestreamwrite_table.contact_events -auto-approve

echo "Done! Check the outputs above for the Timestream resources created."
echo 
echo "To use these Timestream resources with Grafana, update the datasource configuration to point to:"
echo "Database Name: $(terraform output -raw timestream_fixed_database_name 2>/dev/null || echo "N/A")"
echo "Region: eu-west-1"