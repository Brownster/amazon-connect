# ===================================================================
# MAIN TERRAFORM VARIABLES
# ===================================================================
# Global variables that can be customized for the entire deployment

variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "connect-analytics"
}

variable "instance_alias" {
  description = "Alias for the Amazon Connect instance"
  type        = string
  default     = "thebrowns"
}

variable "tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Connect Analytics Pipeline"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

# EC2 Instance Variables
variable "instance_type" {
  description = "EC2 instance type for Grafana"
  type        = string
  default     = "t3.small"
}

# Kinesis Variables
variable "kinesis_shard_count" {
  description = "Number of shards for the Kinesis data stream"
  type        = number
  default     = 1
}

variable "kinesis_retention_period" {
  description = "Retention period for Kinesis data stream (hours)"
  type        = number
  default     = 24
}

# Firehose Variables
variable "firehose_buffer_size" {
  description = "Buffer size for Firehose delivery stream (MB)"
  type        = number
  default     = 5
}

variable "firehose_buffer_interval" {
  description = "Buffer interval for Firehose delivery stream (seconds)"
  type        = number
  default     = 60
}

# SSH Key Variables
variable "ssh_key_path" {
  description = "Path to the SSH public key file for EC2 instance"
  type        = string
  default     = "../grafana-key.pub"
}