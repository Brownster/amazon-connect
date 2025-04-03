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