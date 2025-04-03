# ===================================================================
# ANALYTICS OUTPUTS
# ===================================================================

output "athena_workgroup" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.connect_analytics.name
}

output "athena_results_bucket" {
  description = "S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.bucket
}