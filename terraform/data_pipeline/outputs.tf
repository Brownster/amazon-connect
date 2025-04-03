# ===================================================================
# DATA PIPELINE OUTPUTS
# ===================================================================

output "kinesis_stream_name" {
  description = "Name of the Kinesis stream"
  value       = aws_kinesis_stream.connect_ctr.name
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream"
  value       = aws_kinesis_stream.connect_ctr.arn
}

output "s3_data_bucket" {
  description = "Name of the S3 bucket storing Connect CTR data"
  value       = aws_s3_bucket.connect_ctr_data.bucket
}

output "glue_database_name" {
  description = "Name of the Glue catalog database"
  value       = aws_glue_catalog_database.connect_db.name
}