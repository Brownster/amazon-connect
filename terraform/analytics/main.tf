# ===================================================================
# ANALYTICS INFRASTRUCTURE (ATHENA)
# ===================================================================
# This file defines Athena resources for querying data

# Generate a random string to ensure unique S3 bucket names
resource "random_string" "suffix" {
  length  = var.random_suffix_length
  special = false
  lower   = true
  upper   = false
}

# Create Athena workgroup for querying the data
resource "aws_athena_workgroup" "connect_analytics" {
  name = var.athena_workgroup_name
  
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    
    # Set S3 location for query results
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/output/"
    }
  }
  
  tags = var.tags
}

# Create S3 bucket for Athena query results
resource "aws_s3_bucket" "athena_results" {
  bucket        = "${var.s3_bucket_prefix}-${random_string.suffix.result}"
  force_destroy = var.s3_force_destroy
  
  tags = merge(
    var.tags,
    {
      Name = "${var.s3_bucket_prefix}-${random_string.suffix.result}"
    }
  )
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