# Terraform Modules for AWS Connect Analytics Pipeline

This directory contains the Terraform modules that define the infrastructure for the Amazon Connect analytics pipeline.

## Module Structure

The configuration is divided into the following modules:

### `networking/`
Contains VPC, subnets, internet gateway, and route tables for network infrastructure.

### `connect/` 
Defines the Amazon Connect instance and its configuration for sending CTR data to Kinesis.

### `data_pipeline/`
Contains resources for data flow and processing:
- Kinesis Data Stream
- Kinesis Firehose
- S3 bucket for data storage
- AWS Glue crawler and database

### `analytics/`
Defines Athena workgroup and results storage for querying the data.

### `grafana/`
Contains EC2 instance configuration for Grafana dashboards, including:
- EC2 instance with Docker
- Security group
- IAM roles and policies
- SSH key configuration

## Usage

From the parent directory, initialize and apply the Terraform configuration:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Outputs

The main configuration exports various useful outputs:
- Connect instance ID
- Kinesis stream name
- S3 bucket names
- Grafana access information

## Dependencies

The modules have the following dependencies:

```
networking <-- grafana
data_pipeline <-- connect
analytics <-- grafana
```