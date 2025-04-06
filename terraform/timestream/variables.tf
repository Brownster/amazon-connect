# ===================================================================
# TIMESTREAM MODULE VARIABLES
# ===================================================================

variable "stack_name" {
  description = "A unique name for this stack deployment, used for naming resources"
  type        = string
  default     = "connect-analytics"
}

variable "aws_region" {
  description = "AWS region for Lambda resources (Connect in eu-west-2, Timestream in eu-west-1)"
  type        = string
}

variable "timestream_region" {
  description = "AWS region for Timestream resources (must be a region where Timestream is supported)"
  type        = string
  default     = "eu-west-1"
}

variable "existing_kinesis_stream_arn" {
  description = "ARN of the existing Kinesis stream for CTR data"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "timestream_retention_memory" {
  description = "Timestream memory store retention in hours"
  type        = number
  default     = 25
}

variable "timestream_retention_magnetic" {
  description = "Timestream magnetic store retention in days"
  type        = number
  default     = 365
}

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.9"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions (seconds)"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions (MB)"
  type        = number
  default     = 256
}

variable "kinesis_batch_size" {
  description = "Batch size for Kinesis event source mapping"
  type        = number
  default     = 100
}

variable "kinesis_batch_window" {
  description = "Maximum batching window in seconds for Kinesis event source mapping"
  type        = number
  default     = 5
}

variable "instance_data_schedule" {
  description = "Schedule expression for instance data collection"
  type        = string
  default     = "rate(5 minutes)"
}