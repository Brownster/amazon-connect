# ===================================================================
# AMAZON CONNECT VARIABLES
# ===================================================================

variable "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream for Contact Trace Records"
  type        = string
}