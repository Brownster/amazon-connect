# ===================================================================
# AWS Connect Analytics Pipeline - Main Terraform Configuration
# ===================================================================
# This file defines the infrastructure for an Amazon Connect analytics
# pipeline that processes Contact Trace Records (CTR) through Kinesis,
# Firehose, S3, Glue, and Athena, with a Grafana dashboard for visualization.
# ===================================================================

# Define the AWS provider and region
provider "aws" {
  region = "eu-west-2"
  # Uncomment and fill in your credentials below
  # access_key = "your_access_key"
  # secret_key = "your_secret_key"
  
  # Or use profile from ~/.aws/credentials
  # profile = "default"
}

# ===================================================================
# NETWORKING INFRASTRUCTURE
# ===================================================================
# Create a Virtual Private Cloud (VPC) to host our Grafana instance
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"  # Define IP address range for the VPC
  enable_dns_support   = true           # Enable DNS resolution in the VPC
  enable_dns_hostnames = true           # Enable DNS hostnames in the VPC
  
  tags = {
    Name = "connect-analytics-vpc"
  }
}

# Create a public subnet to host our Grafana instance
# Public subnets have direct route to the internet gateway
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"              # Define IP range for the subnet
  availability_zone       = "eu-west-2a"               # Specify the availability zone
  map_public_ip_on_launch = true                       # Automatically assign public IPs to instances
  
  tags = {
    Name = "connect-analytics-public"
  }
}

# Create a private subnet (not used in current config but available for future use)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"              # Define IP range for the subnet
  availability_zone = "eu-west-2a"               # Specify the availability zone
  
  tags = {
    Name = "connect-analytics-private"
  }
}

# Create an internet gateway to allow communication between VPC and the internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "connect-analytics-igw"
  }
}

# Create a route table for the public subnet with route to internet via IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  # Define a route to the internet (0.0.0.0/0) via the internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "connect-analytics-public-route"
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ===================================================================
# UTILITY RESOURCES
# ===================================================================
# Generate a random string to ensure unique S3 bucket names
resource "random_string" "suffix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
}

# Get current AWS account ID for use in resource configuration
data "aws_caller_identity" "current" {}

# ===================================================================
# AMAZON CONNECT CONFIGURATION
# ===================================================================
# Create an Amazon Connect instance to handle customer interactions
resource "aws_connect_instance" "instance" {
  identity_management_type       = "CONNECT_MANAGED"    # Use Connect's built-in user management
  inbound_calls_enabled          = true                 # Enable inbound calls
  outbound_calls_enabled         = true                 # Enable outbound calls
  early_media_enabled            = true                 # Allow audio before call is connected
  auto_resolve_best_voices_enabled = true               # Use best voice based on caller location
  contact_flow_logs_enabled      = true                 # Enable logging of contact flows
  contact_lens_enabled           = true                 # Enable Contact Lens analytics
  instance_alias                 = "thebrowns"          # Name for the Connect instance
  multi_party_conference_enabled = true                 # Enable multi-party calls
}

# ===================================================================
# DATA STREAMING INFRASTRUCTURE
# ===================================================================
# Create a Kinesis Data Stream to receive Contact Trace Records (CTR) from Connect
resource "aws_kinesis_stream" "connect_ctr" {
  name             = "connect-ctr-stream"
  shard_count      = 1                # Number of shards (throughput units)
  retention_period = 24               # Data retention period in hours
  
  tags = {
    Name = "connect-ctr-stream"
  }
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
        Resource = aws_kinesis_stream.connect_ctr.arn
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
      stream_arn = aws_kinesis_stream.connect_ctr.arn
    }
    storage_type = "KINESIS_STREAM"
  }
}

# ===================================================================
# DATA LAKE CONFIGURATION - GLUE, S3, ATHENA
# ===================================================================
# Create a Glue Catalog Database to store metadata about our data
resource "aws_glue_catalog_database" "connect_db" {
  name = "connect_ctr_database"  # Database name for querying with Athena
}

# IAM Role for Glue Crawler to access S3 and catalog data
resource "aws_iam_role" "glue_crawler" {
  name = "glue-crawler-role"
  
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
}

# Attach AWS managed policy for Glue service roles
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Create S3 bucket to store Connect CTR data from Firehose
resource "aws_s3_bucket" "connect_ctr_data" {
  bucket = "connect-ctr-data-${random_string.suffix.result}"  # Generate unique bucket name
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
  name = "firehose-role"
  
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
}

# IAM Policy for Firehose to read from Kinesis and write to S3
resource "aws_iam_role_policy" "firehose_role" {
  name = "firehose-policy"
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
  name        = "connect-ctr-delivery-stream"
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
    prefix             = "connect-ctr-data/"  # S3 prefix for stored data
    
    buffering_size     = 5  # Buffer size in MB
    buffering_interval = 60 # Buffer interval in seconds
    
    # Disable processing configuration to avoid validation errors
    processing_configuration {
      enabled = false
    }
  }
}

# IAM Policy for Glue Crawler to access S3 data
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "glue-s3-access-policy"
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
  name          = "connect-ctr-crawler"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.connect_db.name
  
  # Set S3 target for the crawler
  s3_target {
    path = "s3://${aws_s3_bucket.connect_ctr_data.bucket}/connect-ctr-data/"
  }
  
  schedule = "cron(0 */3 * * ? *)" # Run every 3 hours
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

# ===================================================================
# GRAFANA INSTANCE CONFIGURATION
# ===================================================================
# Create key pair for SSH access to the Grafana instance
resource "aws_key_pair" "grafana" {
  key_name   = "grafana-key-pair"
  public_key = file("${path.module}/grafana-key.pub")  # Use local SSH public key
}

# Security group for Grafana instance
resource "aws_security_group" "grafana" {
  name        = "grafana-sg"
  description = "Allow traffic for Grafana"
  vpc_id      = aws_vpc.main.id
  
  # Allow SSH traffic from anywhere (restrict this in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP in production
  }
  
  # Allow Grafana web traffic from anywhere (restrict this in production)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP in production
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for Grafana EC2 instance
resource "aws_iam_role" "grafana_instance" {
  name = "grafana-instance-role"
  
  # Trust policy allowing EC2 and self-assume
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/grafana-instance-role"
        }
      }
    ]
  })
}

# IAM Instance Profile for attaching role to EC2
resource "aws_iam_instance_profile" "grafana" {
  name = "grafana-instance-profile"
  role = aws_iam_role.grafana_instance.name
}

# IAM Policy for Grafana to access Athena and S3
resource "aws_iam_role_policy" "grafana_athena" {
  name = "grafana-athena-policy"
  role = aws_iam_role.grafana_instance.id
  
  # Grant permissions to query Athena and access S3 results
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:ListDatabases",
          "athena:ListTableMetadata",
          "athena:GetTableMetadata"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.athena_results.arn,
          "${aws_s3_bucket.athena_results.arn}/*"
        ]
      },
      {
        Action = [
          "glue:GetDatabases",
          "glue:GetTables",
          "glue:GetTable"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Find latest Amazon Linux 2 AMI for EC2 instance
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create EC2 instance for Grafana
resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"              # Instance size
  subnet_id              = aws_subnet.public.id    # Place in public subnet
  vpc_security_group_ids = [aws_security_group.grafana.id]
  iam_instance_profile   = aws_iam_instance_profile.grafana.name
  key_name               = aws_key_pair.grafana.key_name
  
  # Bootstrap script for instance setup
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user
    chkconfig docker on
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Create Grafana Docker Compose file
    mkdir -p /home/ec2-user/grafana
    cat > /home/ec2-user/grafana/docker-compose.yml <<'COMPOSE'
    version: '3'
    services:
      grafana:
        image: grafana/grafana:latest
        container_name: grafana
        restart: unless-stopped
        ports:
          - "3000:3000"
        volumes:
          - grafana-data:/var/lib/grafana
        environment:
          - GF_INSTALL_PLUGINS=grafana-athena-datasource
    volumes:
      grafana-data:
    COMPOSE
    
    cd /home/ec2-user/grafana
    docker-compose up -d
    
    # Wait for Grafana to start
    sleep 10
    
    # Install Athena plugin directly
    docker exec -it grafana grafana-cli plugins install grafana-athena-datasource
    
    # Restart Grafana to apply plugin
    docker-compose restart
  EOF
  
  tags = {
    Name = "grafana-server"
  }
}

# ===================================================================
# OUTPUT VALUES
# ===================================================================
# Define outputs to display after terraform apply
output "connect_instance_id" {
  value = aws_connect_instance.instance.id
}

output "kinesis_stream_name" {
  value = aws_kinesis_stream.connect_ctr.name
}

output "s3_data_bucket" {
  value = aws_s3_bucket.connect_ctr_data.bucket
}

output "athena_database" {
  value = aws_glue_catalog_database.connect_db.name
}

output "grafana_public_ip" {
  value = aws_instance.grafana.public_ip
  description = "Public IP address of the Grafana server. Access Grafana at http://<IP>:3000"
}

output "grafana_ssh_command" {
  value = "ssh -i grafana-key ec2-user@${aws_instance.grafana.public_ip}"
  description = "SSH command to connect to the Grafana instance"
}

output "grafana_default_credentials" {
  value = "Username: admin, Password: admin (you'll be prompted to change on first login)"
  description = "Default Grafana login credentials"
}