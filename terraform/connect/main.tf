# ===================================================================
# AMAZON CONNECT CONFIGURATION
# ===================================================================
# This file defines Amazon Connect instance and related resources

# Create an Amazon Connect instance to handle customer interactions
resource "aws_connect_instance" "instance" {
  identity_management_type       = "CONNECT_MANAGED"    # Use Connect's built-in user management
  inbound_calls_enabled          = true                 # Enable inbound calls
  outbound_calls_enabled         = true                 # Enable outbound calls
  early_media_enabled            = true                 # Allow audio before call is connected
  auto_resolve_best_voices_enabled = true               # Use best voice based on caller location
  contact_flow_logs_enabled      = var.enable_contact_flow_logs  # Enable logging of contact flows
  contact_lens_enabled           = var.enable_contact_lens       # Enable Contact Lens analytics
  instance_alias                 = var.instance_alias            # Name for the Connect instance
  multi_party_conference_enabled = true                          # Enable multi-party calls
  
  tags = var.tags
}

# IAM Role to allow Amazon Connect to write to the Kinesis stream
resource "aws_iam_role" "connect_kinesis" {
  name = "connect-kinesis-role"
  
  # Define which AWS services can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "connect.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy to attach to the role defining what permissions it has
resource "aws_iam_role_policy" "connect_kinesis" {
  name = "connect-kinesis-policy"
  role = aws_iam_role.connect_kinesis.id
  
  # Grant permissions to write to the Kinesis stream
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords",
          "kinesis:DescribeStream"
        ]
        Effect   = "Allow"
        Resource = var.kinesis_stream_arn
      }
    ]
  })
}

# Configure Amazon Connect to send CTR data to Kinesis stream
resource "aws_connect_instance_storage_config" "ctr_kinesis" {
  instance_id   = aws_connect_instance.instance.id
  resource_type = "CONTACT_TRACE_RECORDS"        # Specify we're configuring CTR storage
  
  storage_config {
    kinesis_stream_config {
      stream_arn = var.kinesis_stream_arn
    }
    storage_type = "KINESIS_STREAM"
  }
}