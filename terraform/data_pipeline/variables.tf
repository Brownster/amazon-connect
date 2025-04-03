# ===================================================================
# DATA PIPELINE VARIABLES
# ===================================================================

variable "kinesis_stream_name" {
  description = "Name of the Kinesis data stream"
  type        = string
  default     = "connect-ctr-stream"
}

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

variable "firehose_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  type        = string
  default     = "connect-ctr-delivery-stream"
}

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

variable "s3_prefix" {
  description = "S3 prefix for Firehose delivery"
  type        = string
  default     = "connect-ctr-data/"
}

variable "glue_database_name" {
  description = "Name of the Glue catalog database"
  type        = string
  default     = "connect_ctr_database"
}

variable "glue_crawler_name" {
  description = "Name of the Glue crawler"
  type        = string
  default     = "connect-ctr-crawler"
}

variable "glue_crawler_schedule" {
  description = "Schedule for the Glue crawler (cron expression)"
  type        = string
  default     = "cron(0 */3 * * ? *)" # Run every 3 hours
}

variable "s3_bucket_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
  default     = "connect-ctr-data"
}

variable "s3_force_destroy" {
  description = "Whether the bucket can be destroyed when not empty"
  type        = bool
  default     = false
}

variable "firehose_role_name" {
  description = "Name of the IAM role for Firehose"
  type        = string
  default     = "firehose-role"
}

variable "glue_crawler_role_name" {
  description = "Name of the IAM role for the Glue crawler"
  type        = string
  default     = "glue-crawler-role"
}

variable "firehose_policy_name" {
  description = "Name of the IAM policy for Firehose"
  type        = string
  default     = "firehose-policy"
}

variable "glue_s3_policy_name" {
  description = "Name of the IAM policy for Glue S3 access"
  type        = string
  default     = "glue-s3-access-policy"
}

variable "random_suffix_length" {
  description = "Length of the random suffix for unique resource names"
  type        = number
  default     = 8
}

variable "tags" {
  description = "Tags to apply to data pipeline resources"
  type        = map(string)
  default     = {}
}