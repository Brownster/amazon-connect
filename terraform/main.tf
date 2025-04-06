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
  availability_zone   = "eu-west-2a"  # Changed back to eu-west-2a for compatibility
  
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
# TIMESTREAM MODULE
# ===================================================================
module "timestream" {
  source = "./timestream"
  
  # Pass configuration to timestream module
  stack_name = var.project_name
  aws_region = var.aws_region
  timestream_region = "eu-west-1"  # Explicitly set to a region where Timestream is supported
  existing_kinesis_stream_arn = module.data_pipeline.kinesis_stream_arn
  
  # Pass tags with module-specific prefix
  tags = merge(
    var.tags,
    {
      Module = "Timestream"
    }
  )
  
  # Ensure data pipeline is created first
  depends_on = [module.data_pipeline]
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
  
  # Pass Timestream information (requires updating grafana module)
  timestream_database_name = module.timestream.timestream_database_name
  timestream_database_arn  = module.timestream.timestream_database_arn
  timestream_kms_key_arn   = module.timestream.timestream_kms_key_arn
  
  # Pass tags with module-specific prefix
  tags = merge(
    var.tags,
    {
      Module = "Grafana"
    }
  )
  
  # Ensure timestream module is created first
  depends_on = [module.timestream]
}

# ===================================================================
# OUTPUT VALUES
# ===================================================================
# Define outputs to display after terraform apply

# Original outputs that Terraform expects based on the plan
output "connect_instance_id" {
  value       = module.connect.connect_instance_id
  description = "The ID of the Amazon Connect instance"
}

output "connect_agents" {
  value       = module.connect.connect_agent_details
  description = "Detailed information about the created Connect agents"
}

output "connect_agent_password" {
  value       = module.connect.connect_agent_passwords
  description = "The password for the Connect agents"
  sensitive   = true
}

output "connect_instance_alias" {
  value       = module.connect.connect_instance_alias
  description = "The alias of the Connect instance, used for constructing access URLs"
}

output "kinesis_stream_name" {
  value       = module.data_pipeline.kinesis_stream_name
  description = "The name of the Kinesis stream for CTRs"
}

output "s3_data_bucket" {
  value       = module.data_pipeline.s3_data_bucket
  description = "The name of the S3 bucket for CTR data"
}

output "athena_database" {
  value       = module.data_pipeline.glue_database_name
  description = "The name of the Glue/Athena database"
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

# New outputs with additional information and guidance
output "timestream_database_name" {
  value       = module.timestream.timestream_database_name
  description = "The name of the Timestream database for real-time monitoring"
}

output "timestream_tables" {
  value       = module.timestream.timestream_table_names
  description = "Names of the Timestream tables for different data types"
}

output "deployment_guide" {
  value = <<EOT

╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║    AWS Connect Analytics Pipeline with Timestream Real-time Monitoring     ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

Your AWS Connect Analytics Pipeline has been configured with:
- Historical analytics via S3, Glue, and Athena
- Real-time monitoring via Timestream and pre-built Grafana dashboards
- Automatic data processing with Lambda functions
- Test agents pre-configured for Connect

----- KEY RESOURCES -----
Connect Instance ID: ${module.connect.connect_instance_id}
Kinesis Stream: ${module.data_pipeline.kinesis_stream_name}
S3 Data Bucket: ${module.data_pipeline.s3_data_bucket}
Athena Database: ${module.data_pipeline.glue_database_name}
Timestream Database: ${module.timestream.timestream_database_name}
Grafana URL: http://${module.grafana.grafana_public_ip}:3000
Grafana Login: ${module.grafana.grafana_default_credentials}

----- CONNECT AGENTS -----
The following test agents have been created in your Connect instance:
${join("\n", [for username, agent in module.connect.connect_agent_details : "- ${agent.first_name} ${agent.last_name} (${username}) - ${agent.email}"])}

Agent Password: Use the 'terraform output -json connect_agent_password' command to retrieve the password

Agent Login URL: https://${module.connect.connect_instance_alias}.my.connect.aws/ccp-v2/

To login to the agent panel:
1. Go to the URL above
2. Enter the username (e.g., sales.agent)
3. Enter the password from the command above
4. You'll be connected to the Contact Control Panel (CCP)

----- AFTER DEPLOYMENT CHECKLIST -----
1. Access Amazon Connect admin panel: https://${module.connect.connect_instance_alias}.my.connect.aws/
2. Sign in to the agent CCP: https://${module.connect.connect_instance_alias}.my.connect.aws/ccp-v2/
3. Generate test data: run "./scripts/generate_ctr_data.py"
4. Verify data flow in CloudWatch, S3, and Timestream
5. Access pre-built dashboards in Grafana
6. Configure alerts based on your monitoring needs

For detailed documentation, please refer to:
- docs/connect_setup.md
- docs/grafana_athena_setup.md
- docs/prometheus_cloudwatch_monitoring.md
- working/implementation_summary.md
EOT
  description = "A comprehensive guide to your deployment with next steps"
}