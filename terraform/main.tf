# ===================================================================
# AWS Connect Analytics Pipeline - Main Terraform Configuration
# ===================================================================
# This is the main entry point for our Terraform configuration
# It imports all the modules and connects them together
# ===================================================================

# Define the AWS provider and region
provider "aws" {
  region = "eu-west-2"
  # Uncomment and fill in your credentials below
  # access_key = "your_access_key"
  # secret_key = "your_secret_key"
  
  # Or use profile from ~/.aws/credentials
  # profile = "default"
}

# ===================================================================
# NETWORKING MODULE
# ===================================================================
module "networking" {
  source = "./networking"
}

# ===================================================================
# DATA PIPELINE MODULE
# ===================================================================
module "data_pipeline" {
  source = "./data_pipeline"
}

# ===================================================================
# CONNECT MODULE
# ===================================================================
module "connect" {
  source = "./connect"
  
  # Pass data pipeline outputs to connect module
  kinesis_stream_arn = module.data_pipeline.kinesis_stream_arn
}

# ===================================================================
# ANALYTICS MODULE
# ===================================================================
module "analytics" {
  source = "./analytics"
}

# ===================================================================
# GRAFANA MODULE
# ===================================================================
module "grafana" {
  source = "./grafana"
  
  # Pass networking outputs to grafana module
  vpc_id    = module.networking.vpc_id
  subnet_id = module.networking.public_subnet_id
  
  # Pass analytics outputs to grafana module
  athena_results_bucket = module.analytics.athena_results_bucket
}

# ===================================================================
# OUTPUT VALUES
# ===================================================================
# Define outputs to display after terraform apply

output "connect_instance_id" {
  value = module.connect.connect_instance_id
}

output "kinesis_stream_name" {
  value = module.data_pipeline.kinesis_stream_name
}

output "s3_data_bucket" {
  value = module.data_pipeline.s3_data_bucket
}

output "athena_database" {
  value = module.data_pipeline.glue_database_name
}

output "grafana_public_ip" {
  value       = module.grafana.grafana_public_ip
  description = "Public IP address of the Grafana server. Access Grafana at http://<IP>:3000"
}

output "grafana_ssh_command" {
  value       = module.grafana.grafana_ssh_command
  description = "SSH command to connect to the Grafana instance"
}

output "grafana_default_credentials" {
  value       = module.grafana.grafana_default_credentials
  description = "Default Grafana login credentials"
}