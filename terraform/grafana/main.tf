# ===================================================================
# GRAFANA INSTANCE CONFIGURATION
# ===================================================================
# This file defines EC2 and related resources for Grafana visualization

# Get current AWS account ID for use in resource configuration
data "aws_caller_identity" "current" {}

# Create key pair for SSH access to the Grafana instance
resource "aws_key_pair" "grafana" {
  key_name   = "grafana-key-pair"
  public_key = file("${path.module}/../../grafana-key.pub")  # Use local SSH public key
}

# Security group for Grafana instance
resource "aws_security_group" "grafana" {
  name        = "grafana-sg"
  description = "Allow traffic for Grafana"
  vpc_id      = var.vpc_id
  
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
          "arn:aws:s3:::${var.athena_results_bucket}",
          "arn:aws:s3:::${var.athena_results_bucket}/*"
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
  subnet_id              = var.subnet_id           # Place in public subnet
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