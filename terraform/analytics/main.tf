# ===================================================================
# ANALYTICS INFRASTRUCTURE (ATHENA)
# ===================================================================
# This file defines Athena resources for querying data

# Generate a random string to ensure unique S3 bucket names
resource "random_string" "suffix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
}

# Create Athena workgroup for querying the data
resource "aws_athena_workgroup" "connect_analytics" {
  name = "connect-analytics"
  
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    
    # Set S3 location for query results
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/output/"
    }
  }
}

# Create S3 bucket for Athena query results
resource "aws_s3_bucket" "athena_results" {
  bucket = "connect-analytics-athena-results-${random_string.suffix.result}"
}

# Set S3 bucket ownership controls for Athena results
resource "aws_s3_bucket_ownership_controls" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Set S3 bucket ACL to private for security
resource "aws_s3_bucket_acl" "athena_results" {
  depends_on = [aws_s3_bucket_ownership_controls.athena_results]
  bucket     = aws_s3_bucket.athena_results.id
  acl        = "private"
}