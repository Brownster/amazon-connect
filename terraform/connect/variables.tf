# ===================================================================
# AMAZON CONNECT VARIABLES
# ===================================================================

variable "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream for Contact Trace Records"
  type        = string
}

variable "instance_alias" {
  description = "Alias for the Amazon Connect instance"
  type        = string
  default     = "thebrowns"
}

variable "enable_contact_lens" {
  description = "Whether to enable Contact Lens analytics"
  type        = bool
  default     = true
}

variable "enable_contact_flow_logs" {
  description = "Whether to enable Contact Flow logs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to Connect resources"
  type        = map(string)
  default     = {}
}