# ===================================================================
# GRAFANA VARIABLES
# ===================================================================

variable "vpc_id" {
  description = "ID of the VPC where Grafana will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where Grafana will be deployed"
  type        = string
}

variable "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena query results"
  type        = string
}

variable "athena_workgroup" {
  description = "Name of the Athena workgroup"
  type        = string
  default     = "connect-analytics"
}

variable "glue_database_name" {
  description = "Name of the Glue/Athena database"
  type        = string
  default     = "connect_ctr_database"
}

# Timestream variables
variable "timestream_database_name" {
  description = "Name of the Timestream database"
  type        = string
}

variable "timestream_database_arn" {
  description = "ARN of the Timestream database"
  type        = string
}

variable "timestream_kms_key_arn" {
  description = "ARN of the KMS key used for Timestream encryption"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance type for Grafana"
  type        = string
  default     = "t3.small"
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair for EC2 instance"
  type        = string
  default     = "grafana-key-pair"
}

variable "ssh_key_path" {
  description = "Path to the SSH public key file for EC2 instance"
  type        = string
  default     = "../../grafana-key.pub"
}

variable "grafana_role_name" {
  description = "Name of the IAM role for Grafana instance"
  type        = string
  default     = "grafana-instance-role"
}

variable "grafana_profile_name" {
  description = "Name of the IAM instance profile for Grafana instance"
  type        = string
  default     = "grafana-instance-profile"
}

variable "grafana_policy_name" {
  description = "Name of the IAM policy for Grafana instance"
  type        = string
  default     = "grafana-athena-policy"
}

variable "security_group_name" {
  description = "Name of the security group for Grafana instance"
  type        = string
  default     = "grafana-sg"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block to allow SSH access to the Grafana instance"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_grafana_cidr" {
  description = "CIDR block to allow web access to the Grafana instance"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Tags to apply to Grafana resources"
  type        = map(string)
  default     = {
    Name = "grafana-server"
  }
}

variable "yace_namespaces" {
  description = "List of CloudWatch namespaces to monitor with YACE"
  type = list(object({
    name       = string
    dimensions = optional(list(object({
      name  = string
      value = string
    })))
    metrics = list(object({
      name       = string
      statistics = list(string)
    }))
  }))
  default = [
    {
      name = "AWS/Connect"
      metrics = [
        {
          name       = "CallsPerInterval"
          statistics = ["Sum"]
        },
        {
          name       = "ContactFlowErrors"
          statistics = ["Sum"]
        },
        {
          name       = "MissedCalls"
          statistics = ["Sum"]
        },
        {
          name       = "CallBackNotDialableNumber"
          statistics = ["Sum"]
        },
        {
          name       = "CallRecordingUploadError"
          statistics = ["Sum"]
        },
        {
          name       = "CallsBreachingConcurrencyQuota"
          statistics = ["Sum"]
        },
        {
          name       = "ConcurrentCalls"
          statistics = ["Maximum"]
        },
        {
          name       = "ConcurrentCallsPercentage"
          statistics = ["Maximum"]
        },
        {
          name       = "ThrottledCalls"
          statistics = ["Sum"]
        }
      ]
    },
    {
      name = "AWS/Kinesis"
      dimensions = [
        {
          name  = "StreamName"
          value = "connect-ctr-stream"
        }
      ]
      metrics = [
        {
          name       = "GetRecords.IteratorAgeMilliseconds"
          statistics = ["Maximum"]
        },
        {
          name       = "IncomingBytes"
          statistics = ["Sum"]
        },
        {
          name       = "IncomingRecords"
          statistics = ["Sum"]
        },
        {
          name       = "ReadProvisionedThroughputExceeded"
          statistics = ["Sum"]
        }
      ]
    }
  ]
}

# Prometheus and monitoring variables
variable "prometheus_version" {
  description = "Prometheus version to install"
  type        = string
  default     = "2.45.0"
}

variable "node_exporter_version" {
  description = "Node Exporter version to install"
  type        = string
  default     = "1.6.1"
}

variable "yace_version" {
  description = "Yet Another CloudWatch Exporter version"
  type        = string
  default     = "0.48.0-alpha"
}

variable "allowed_prometheus_cidr" {
  description = "CIDR block for Prometheus web UI access"
  type        = string
  default     = "0.0.0.0/0" # Restrict this in production
}

variable "scrape_interval" {
  description = "Prometheus scrape interval in seconds"
  type        = number
  default     = 60
}

variable "retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 15
}
