# ===================================================================
# AWS Connect Analytics Pipeline - Main Terraform Configuration
# ===================================================================
# This is the main entry point for our Terraform configuration
# It imports all the modules and connects them together
# ===================================================================

# Define the AWS provider and region
provider "aws" {
  region = var.aws_region
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
  
  # Pass variables to the networking module
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  availability_zone   = "eu-west-2a"
  
  # Pass tags with module-specific prefix
  tags = merge(
    var.tags,
    {
      Module = "Networking"
    }
  )
}

# ===================================================================
# DATA PIPELINE MODULE
# ===================================================================
module "data_pipeline" {
  source = "./data_pipeline"
  
  # Pass Kinesis configuration
  kinesis_stream_name     = "${var.project_name}-ctr-stream"
  kinesis_shard_count     = var.kinesis_shard_count
  kinesis_retention_period = var.kinesis_retention_period
  
  # Pass Firehose configuration
  firehose_name           = "${var.project_name}-delivery-stream"
  firehose_buffer_size    = var.firehose_buffer_size
  firehose_buffer_interval = var.firehose_buffer_interval
  
  # Pass tags with module-specific prefix
  tags = merge(
    var.tags,
    {
      Module = "DataPipeline"
    }
  )
}

# ===================================================================
# CONNECT MODULE
# ===================================================================
module "connect" {
  source = "./connect"
  
  # Pass data pipeline outputs to connect module
  kinesis_stream_arn = module.data_pipeline.kinesis_stream_arn
  
  # Pass configuration variables
  instance_alias         = var.instance_alias
  enable_contact_lens    = true
  enable_contact_flow_logs = true
  
  # Pass tags with module-specific prefix
  tags = merge(
    var.tags,
    {
      Module = "Connect"
    }
  )
}

# ===================================================================
# ANALYTICS MODULE
# ===================================================================
module "analytics" {
  source = "./analytics"
  
  # Pass analytics configuration
  athena_workgroup_name = "${var.project_name}-workgroup"
  s3_bucket_prefix = "${var.project_name}-athena-results"
  
  # Pass tags with module-specific prefix
  tags = merge(
    var.tags,
    {
      Module = "Analytics"
    }
  )
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
  
  # Pass instance configuration
  instance_type = var.instance_type
  ssh_key_path = var.ssh_key_path
  
  # Pass tags with module-specific prefix
  tags = merge(
    var.tags,
    {
      Module = "Grafana"
    }
  )
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