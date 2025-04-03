# Terraform Guide for AWS Connect Analytics Pipeline

This guide explains the structure and purpose of each Terraform file in the project for those who are new to Terraform or this project's infrastructure.

## What is Terraform?

Terraform is an Infrastructure as Code (IaC) tool that allows you to define, provision, and manage cloud infrastructure using a declarative configuration language. Instead of manually setting up resources through cloud provider consoles, you define your infrastructure in code, which can be versioned, reused, and shared.

## Project Structure Overview

The Terraform configuration for this project is organized in a modular structure:

```
terraform/
├── main.tf                # Main entry point that connects all modules
├── variables.tf           # Global variables for the entire infrastructure
├── versions.tf            # Terraform and provider version constraints
├── networking/            # VPC and networking infrastructure
├── connect/               # Amazon Connect instance configuration
├── data_pipeline/         # Data streaming and storage resources
├── analytics/             # Athena analytics components
└── grafana/               # Grafana visualization server
```

Each module contains at least three key files:
- `main.tf`: Contains the resource definitions
- `variables.tf`: Defines input variables for the module
- `outputs.tf`: Specifies values that the module will expose to other modules

## Root Module Files

### `main.tf`

This is the primary entry point for the Terraform configuration. It does these key things:

1. **Configures the AWS provider** with region and optional authentication details
2. **Imports each module** and connects them together
3. **Passes variables** from the root module to child modules
4. **Defines outputs** to display after deployment

```hcl
# Example snippet
provider "aws" {
  region = var.aws_region  # Uses variable for the region
}

module "networking" {
  source = "./networking"
  # Variables are passed to customize the module
  vpc_cidr = "10.0.0.0/16"
  # Tags are merged with common tags
  tags = merge(var.tags, { Module = "Networking" })
}
```

### `variables.tf`

This file defines global variables that can be customized for the entire infrastructure:

```hcl
variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"  # Default value if not specified
}

variable "environment" {
  description = "Environment name (e.g., dev, test, prod)"
  type        = string
  default     = "dev"
}
```

Each variable has:
- A description explaining its purpose
- A type (string, number, bool, map, etc.)
- An optional default value

### `versions.tf`

Specifies version constraints for Terraform and providers to ensure compatibility:

```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}
```

## Module: networking

This module sets up the basic network infrastructure:

### `networking/main.tf`

Contains resources for the Virtual Private Cloud (VPC):

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = merge(var.tags, { Name = "connect-analytics-vpc" })
}
```

Key resources:
- **VPC**: The isolated network environment
- **Subnets**: Public and private network segments
- **Internet Gateway**: Allows communication with the internet
- **Route Tables**: Define how network traffic is directed

### `networking/variables.tf`

Defines variables specific to networking resources:

```hcl
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
```

### `networking/outputs.tf`

Exposes values that other modules need:

```hcl
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the VPC"
}
```

## Module: connect

This module configures an Amazon Connect instance:

### `connect/main.tf`

Sets up an Amazon Connect contact center instance:

```hcl
resource "aws_connect_instance" "instance" {
  instance_alias           = var.instance_alias
  contact_lens_enabled     = var.enable_contact_lens
  contact_flow_logs_enabled = var.enable_contact_flow_logs
  
  tags = var.tags
}
```

It also configures:
- IAM roles for Connect to access Kinesis
- Integration with Kinesis for Contact Trace Records (CTR)

## Module: data_pipeline

This module creates the data processing pipeline:

### `data_pipeline/main.tf`

Sets up data flow and storage components:

```hcl
# Kinesis stream to receive CTRs
resource "aws_kinesis_stream" "connect_ctr" {
  name             = var.kinesis_stream_name
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_period
  
  tags = merge(var.tags, { Name = var.kinesis_stream_name })
}

# Firehose to deliver data to S3
resource "aws_kinesis_firehose_delivery_stream" "connect_ctr" {
  name        = var.firehose_name
  destination = "extended_s3"
  
  # Configuration for Kinesis source and S3 destination with optimized partitioning
  extended_s3_configuration {
    # Time-based partitioning for improved query performance
    prefix = "${var.s3_prefix}year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    
    # Error handling with separate partition structure
    error_output_prefix = "${var.s3_prefix_error}!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
  }
}
```

Key components:
- **Kinesis Data Stream**: Receives real-time CTR data
- **Firehose Delivery Stream**: Buffers and delivers data to S3 with time-based partitioning
- **S3 Bucket**: Stores the CTR data in an optimized partition structure
- **Glue Crawler**: Discovers the schema and automatically recognizes partition structure
- **Glue Catalog Database**: Stores metadata about the data, including partition information

The Glue Crawler is configured to handle the partitioned data structure:

```hcl
resource "aws_glue_crawler" "connect_ctr" {
  # Basic configuration...
  
  # Configuration for partitioning
  configuration = var.enable_s3_partitioning ? jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
    # Configure to understand the time-based partition structure
    Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
  }) : null
  
  # Schema change policy
  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
}
```

This configuration allows the crawler to automatically detect and register the partitions in the Glue Data Catalog.

### Optimized S3 Partitioning

The data pipeline implements time-based partitioning for S3 data:

```
connect-ctr-data/
├── year=2023/
│   └── month=12/
│       └── day=15/
│           └── hour=14/
│               └── data files
```

This partitioning structure:
- Improves Athena query performance by allowing partition pruning
- Reduces query costs by scanning only relevant data
- Simplifies data lifecycle management with clear time boundaries

### `data_pipeline/variables.tf`

Key partitioning variables:

```hcl
variable "s3_prefix" {
  description = "Base S3 prefix for Firehose delivery"
  type        = string
  default     = "connect-ctr-data/"
}

variable "s3_prefix_error" {
  description = "S3 prefix for Firehose delivery errors"
  type        = string
  default     = "connect-ctr-data-errors/"
}

variable "enable_s3_partitioning" {
  description = "Enable time-based partitioning for S3 data"
  type        = bool
  default     = true
}
```

These variables control the S3 data partitioning behavior and can be customized for different environments.

## Module: analytics

This module sets up the analytics layer:

### `analytics/main.tf`

Configures Athena for SQL queries on your data:

```hcl
resource "aws_athena_workgroup" "connect_analytics" {
  name = var.athena_workgroup_name
  
  configuration {
    # Output configuration for query results...
  }
  
  tags = var.tags
}
```

Key components:
- **Athena Workgroup**: Enables queries on CTR data
- **S3 Bucket**: Stores Athena query results

### Querying Partitioned Data

The time-based partitioning scheme allows for efficient queries in Athena:

```sql
-- Simple query (scans all data):
SELECT * 
FROM connect_ctr_database.connect_ctr_data 
LIMIT 10;

-- Efficient query using partitions (scans less data):
SELECT * 
FROM connect_ctr_database.connect_ctr_data 
WHERE year='2023' AND month='12' AND day='15' 
LIMIT 10;

-- Time range query:
SELECT * 
FROM connect_ctr_database.connect_ctr_data 
WHERE 
  (year='2023' AND month='12' AND day='15') OR
  (year='2023' AND month='12' AND day='16')
ORDER BY initializationtimestamp 
LIMIT 100;
```

These partition-aware queries significantly improve performance and reduce cost by scanning only the data you need.

## Module: grafana

This module deploys Grafana for visualization:

### `grafana/main.tf`

Provisions an EC2 instance with Grafana:

```hcl
resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  
  # User data script to set up Docker and Grafana...
  
  tags = var.tags
}
```

Key components:
- **EC2 Instance**: Runs Grafana in Docker
- **Security Group**: Controls network access
- **IAM Role**: Allows Grafana to access Athena
- **SSH Key**: For secure access to the instance

## How Variables Flow Through the Infrastructure

1. Root `variables.tf` defines global settings (region, tags, etc.)
2. `main.tf` passes variables to each module
3. Each module has its own variables with defaults
4. Resources use the variables for configuration

Example flow:
```
Root variables.tf:
 var.instance_type = "t3.small"
 
Main.tf:
 module "grafana" {
   instance_type = var.instance_type
 }
 
Grafana variables.tf:
 variable "instance_type" {
   default = "t3.small"  # Will be overridden by the passed value
 }
 
Grafana main.tf:
 resource "aws_instance" "grafana" {
   instance_type = var.instance_type  # Receives the value
 }
```

## How Resources Connect Together

Resources connect through references and outputs:

1. The `networking` module creates a VPC and subnets
2. It exposes the IDs through outputs
3. The `grafana` module uses these outputs to place its EC2 instance in the right network

```
# Networking module exposes VPC ID
output "vpc_id" {
  value = aws_vpc.main.id
}

# Grafana module uses the VPC ID
module "grafana" {
  vpc_id = module.networking.vpc_id
}
```

## Common Terraform Commands

- `terraform init`: Initialize the working directory
- `terraform plan`: Preview changes before applying
- `terraform apply`: Apply the configuration to create/update resources
- `terraform destroy`: Remove all resources defined in the configuration

## Customizing the Deployment

To customize the deployment, modify variables in one of these ways:

1. Edit `terraform.tfvars` (create if it doesn't exist)
2. Pass variables on the command line: `terraform apply -var="instance_type=t3.medium"`
3. Use environment variables: `export TF_VAR_instance_type=t3.medium`

## Best Practices

1. **Always run `terraform plan` before `apply`** to review changes
2. **Use variables instead of hardcoding values** for flexibility
3. **Apply proper tagging** to resources for organization
4. **Use modules for reusable components** of infrastructure
5. **Store state remotely** for team collaboration (e.g., S3 + DynamoDB)
6. **Version control your Terraform code** to track changes

This guide should help you understand the overall structure and purpose of each Terraform file in the project. For more detailed information on Terraform, refer to the [official documentation](https://developer.hashicorp.com/terraform/docs).