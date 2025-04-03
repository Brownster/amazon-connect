# ===================================================================
# ANALYTICS VARIABLES
# ===================================================================

variable "athena_workgroup_name" {
  description = "Name of the Athena workgroup"
  type        = string
  default     = "connect-analytics"
}

variable "s3_bucket_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
  default     = "connect-analytics-athena-results"
}

variable "random_suffix_length" {
  description = "Length of the random suffix for unique resource names"
  type        = number
  default     = 8
}

variable "s3_force_destroy" {
  description = "Whether the bucket can be destroyed when not empty"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to analytics resources"
  type        = map(string)
  default     = {}
}