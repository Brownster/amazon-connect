provider "aws" {
  region = "eu-west-2"
  # Uncomment and fill in your credentials below
  # access_key = "your_access_key"
  # secret_key = "your_secret_key"
  
  # Or use profile from ~/.aws/credentials
  # profile = "default"
}

# VPC for hosting Grafana
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "connect-analytics-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "connect-analytics-public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-2a"
  
  tags = {
    Name = "connect-analytics-private"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "connect-analytics-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "connect-analytics-public-route"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Random string for unique bucket names
resource "random_string" "suffix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Amazon Connect Instance
resource "aws_connect_instance" "instance" {
  identity_management_type       = "CONNECT_MANAGED"
  inbound_calls_enabled          = true
  outbound_calls_enabled         = true
  early_media_enabled            = true
  auto_resolve_best_voices_enabled = true
  contact_flow_logs_enabled      = true
  contact_lens_enabled           = true
  instance_alias                 = "thebrowns"
  multi_party_conference_enabled = true
}

# Kinesis Data Stream for Connect CTR data
resource "aws_kinesis_stream" "connect_ctr" {
  name             = "connect-ctr-stream"
  shard_count      = 1
  retention_period = 24
  
  tags = {
    Name = "connect-ctr-stream"
  }
}

# IAM Role for Connect to write to Kinesis
resource "aws_iam_role" "connect_kinesis" {
  name = "connect-kinesis-role"
  
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

resource "aws_iam_role_policy" "connect_kinesis" {
  name = "connect-kinesis-policy"
  role = aws_iam_role.connect_kinesis.id
  
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

# Connect to Kinesis Data Stream Integration
resource "aws_connect_instance_storage_config" "ctr_kinesis" {
  instance_id   = aws_connect_instance.instance.id
  resource_type = "CONTACT_TRACE_RECORDS"
  
  storage_config {
    kinesis_stream_config {
      stream_arn = aws_kinesis_stream.connect_ctr.arn
    }
    storage_type = "KINESIS_STREAM"
  }
}

# Glue Database
resource "aws_glue_catalog_database" "connect_db" {
  name = "connect_ctr_database"
}

# Glue Crawler IAM Role
resource "aws_iam_role" "glue_crawler" {
  name = "glue-crawler-role"
  
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

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# S3 bucket for storing Connect CTR data
resource "aws_s3_bucket" "connect_ctr_data" {
  bucket = "connect-ctr-data-${random_string.suffix.result}"
}

resource "aws_s3_bucket_ownership_controls" "connect_ctr_data" {
  bucket = aws_s3_bucket.connect_ctr_data.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "connect_ctr_data" {
  depends_on = [aws_s3_bucket_ownership_controls.connect_ctr_data]
  bucket     = aws_s3_bucket.connect_ctr_data.id
  acl        = "private"
}

# IAM role for Firehose
resource "aws_iam_role" "firehose_role" {
  name = "firehose-role"
  
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

# Kinesis Firehose to deliver data to S3
resource "aws_kinesis_firehose_delivery_stream" "connect_ctr" {
  name        = "connect-ctr-delivery-stream"
  destination = "extended_s3"
  
  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.connect_ctr.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }
  
  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = aws_s3_bucket.connect_ctr_data.arn
    prefix             = "connect-ctr-data/"
    
    buffering_size     = 5
    buffering_interval = 60
    
    # Disable processing configuration
    processing_configuration {
      enabled = false
    }
  }
}

# Grant S3 access to Glue crawler
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

# Glue Crawler for CTR data in S3
resource "aws_glue_crawler" "connect_ctr" {
  name          = "connect-ctr-crawler"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.connect_db.name
  
  s3_target {
    path = "s3://${aws_s3_bucket.connect_ctr_data.bucket}/connect-ctr-data/"
  }
  
  schedule = "cron(0 */3 * * ? *)" # Run every 3 hours
}

# Athena Workgroup
resource "aws_athena_workgroup" "connect_analytics" {
  name = "connect-analytics"
  
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/output/"
    }
  }
}

# S3 Bucket for Athena query results
resource "aws_s3_bucket" "athena_results" {
  bucket = "connect-analytics-athena-results-${random_string.suffix.result}"
}

resource "aws_s3_bucket_ownership_controls" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "athena_results" {
  depends_on = [aws_s3_bucket_ownership_controls.athena_results]
  bucket     = aws_s3_bucket.athena_results.id
  acl        = "private"
}

# Create a key pair for SSH access
resource "aws_key_pair" "grafana" {
  key_name   = "grafana-key-pair"
  public_key = file("${path.module}/grafana-key.pub")
}

# EC2 instance for Grafana in the VPC
resource "aws_security_group" "grafana" {
  name        = "grafana-sg"
  description = "Allow traffic for Grafana"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP in production
  }
  
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this to your IP in production
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "grafana_instance" {
  name = "grafana-instance-role"
  
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

resource "aws_iam_instance_profile" "grafana" {
  name = "grafana-instance-profile"
  role = aws_iam_role.grafana_instance.name
}

resource "aws_iam_role_policy" "grafana_athena" {
  name = "grafana-athena-policy"
  role = aws_iam_role.grafana_instance.id
  
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

# Lookup for the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.grafana.id]
  iam_instance_profile   = aws_iam_instance_profile.grafana.name
  key_name               = aws_key_pair.grafana.key_name
  
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

# Output values
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