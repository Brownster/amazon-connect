# ===================================================================
# DATA STREAMING INFRASTRUCTURE
# ===================================================================
# This file defines Kinesis, Firehose, S3, and Glue resources for data processing

# Generate a random string to ensure unique S3 bucket names
resource "random_string" "suffix" {
  length  = var.random_suffix_length
  special = false
  lower   = true
  upper   = false
}

# Create a Kinesis Data Stream to receive Contact Trace Records (CTR) from Connect
resource "aws_kinesis_stream" "connect_ctr" {
  name             = var.kinesis_stream_name
  shard_count      = var.kinesis_shard_count      # Number of shards (throughput units)
  retention_period = var.kinesis_retention_period # Data retention period in hours
  
  tags = merge(
    var.tags,
    {
      Name = var.kinesis_stream_name
    }
  )
}

# Create S3 bucket to store Connect CTR data from Firehose
resource "aws_s3_bucket" "connect_ctr_data" {
  bucket        = "${var.s3_bucket_prefix}-${random_string.suffix.result}"  # Generate unique bucket name
  force_destroy = var.s3_force_destroy
  
  tags = merge(
    var.tags,
    {
      Name = "${var.s3_bucket_prefix}-${random_string.suffix.result}"
    }
  )
}

# Set S3 bucket ownership controls to avoid permission issues
resource "aws_s3_bucket_ownership_controls" "connect_ctr_data" {
  bucket = aws_s3_bucket.connect_ctr_data.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Set S3 bucket ACL to private for security
resource "aws_s3_bucket_acl" "connect_ctr_data" {
  depends_on = [aws_s3_bucket_ownership_controls.connect_ctr_data]
  bucket     = aws_s3_bucket.connect_ctr_data.id
  acl        = "private"
}

# IAM Role for Kinesis Firehose delivery stream
resource "aws_iam_role" "firehose_role" {
  name = var.firehose_role_name
  
  # Allow Firehose service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# IAM Policy for Firehose to read from Kinesis and write to S3
resource "aws_iam_role_policy" "firehose_role" {
  name = var.firehose_policy_name
  role = aws_iam_role.firehose_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Effect   = "Allow"
        Resource = aws_kinesis_stream.connect_ctr.arn
      },
      {
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.connect_ctr_data.arn,
          "${aws_s3_bucket.connect_ctr_data.arn}/*"
        ]
      }
    ]
  })
}

# Create Kinesis Firehose delivery stream to move data from Kinesis to S3
resource "aws_kinesis_firehose_delivery_stream" "connect_ctr" {
  name        = var.firehose_name
  destination = "extended_s3"  # Use S3 as destination
  
  # Configure Kinesis as the source
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.connect_ctr.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }
  
  # Configure S3 as the destination
  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.connect_ctr_data.arn
    
    # Use time-based partitioning if enabled, otherwise use simple prefix
    prefix             = var.enable_s3_partitioning ? "${var.s3_prefix}year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/" : var.s3_prefix
    
    # Add error output prefix for better debugging
    error_output_prefix = var.enable_s3_partitioning ? "${var.s3_prefix_error}!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/" : "${var.s3_prefix_error}!{firehose:error-output-type}/"
    
    buffering_size     = var.firehose_buffer_size  # Buffer size in MB
    buffering_interval = var.firehose_buffer_interval # Buffer interval in seconds
    
    # Disable processing configuration to avoid validation errors
    processing_configuration {
      enabled = false
    }
  }
  
  tags = merge(
    var.tags,
    {
      Name = var.firehose_name
    }
  )
}

# Create a Glue Catalog Database to store metadata about our data
resource "aws_glue_catalog_database" "connect_db" {
  name = var.glue_database_name  # Database name for querying with Athena
  
  tags = var.tags
}

# IAM Role for Glue Crawler to access S3 and catalog data
resource "aws_iam_role" "glue_crawler" {
  name = var.glue_crawler_role_name
  
  # Allow Glue service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Attach AWS managed policy for Glue service roles
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# IAM Policy for Glue Crawler to access S3 data
resource "aws_iam_role_policy" "glue_s3_access" {
  name = var.glue_s3_policy_name
  role = aws_iam_role.glue_crawler.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.connect_ctr_data.arn,
          "${aws_s3_bucket.connect_ctr_data.arn}/*"
        ]
      }
    ]
  })
}

# Create Glue Crawler to discover and catalog schema of CTR data in S3
resource "aws_glue_crawler" "connect_ctr" {
  name          = var.glue_crawler_name
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.connect_db.name
  
  # Set S3 target for the crawler
  s3_target {
    path = "s3://${aws_s3_bucket.connect_ctr_data.bucket}/${var.s3_prefix}"
  }
  
  schedule = var.glue_crawler_schedule # Configurable schedule
  
  # Configure the crawler to handle partitioning
  configuration = var.enable_s3_partitioning ? jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
    # Configure to understand the time-based partition structure
    Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
  }) : null
  
  # Set table level configuration
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
  
  tags = merge(
    var.tags,
    {
      Name = var.glue_crawler_name
    }
  )
}