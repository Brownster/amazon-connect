# Multi-Region Setup for Amazon Connect Analytics

This document explains the multi-region architecture used in the Amazon Connect analytics pipeline.

## Regional Architecture

This project uses a multi-region architecture:

- **eu-west-2 (London)**: Primary region for most resources
  - Amazon Connect instance
  - Kinesis Data Stream
  - S3 buckets
  - Glue database and crawler
  - Athena workgroup
  - Grafana EC2 instance

- **eu-west-1 (Ireland)**: Secondary region for Timestream
  - Timestream database and tables
  - KMS keys for Timestream encryption

## Why Multi-Region?

As of this implementation, Amazon Timestream is not available in the eu-west-2 (London) region. The available regions for Timestream are:

- us-east-1 (N. Virginia)
- us-east-2 (Ohio)
- us-west-2 (Oregon)
- eu-west-1 (Ireland)
- eu-central-1 (Frankfurt)
- ap-southeast-1 (Singapore)
- ap-northeast-1 (Tokyo)

We've chosen **eu-west-1 (Ireland)** as it is geographically closest to our primary region (London).

## IAM Permissions

To support this multi-region architecture, the following IAM permissions are required:

1. For Timestream in eu-west-1:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "timestream:*"
     ],
     "Resource": "*"
   }
   ```

2. For KMS key management:
   ```json
   {
     "Effect": "Allow",
     "Action": [
       "kms:DescribeKey",
       "kms:CreateKey",
       "kms:GenerateDataKey",
       "kms:Decrypt"
     ],
     "Resource": "*"
   }
   ```

These permissions are built into the Terraform configuration for the Grafana EC2 instance role.

## Terraform Configuration

The Terraform configuration handles this multi-region setup transparently:

1. In `main.tf`, we use the primary provider (eu-west-2) for most resources
2. In `timestream/main.tf`, we define a separate provider specifically for Timestream:
   ```hcl
   provider "aws" {
     alias  = "timestream"
     region = var.timestream_region  # Default: eu-west-1
   }
   ```
3. All Timestream resources are created with the `provider = aws.timestream` specification

## Data Flow

The data flow in this multi-region setup is:

1. Contact events are captured in eu-west-2 (London) by Amazon Connect
2. Events flow to Kinesis Stream in eu-west-2
3. Data has two paths:
   - **Historical path**: Kinesis → Firehose → S3 → Glue → Athena (all in eu-west-2)
   - **Real-time path**: Kinesis → Lambda → Timestream (in eu-west-1)
4. Grafana (in eu-west-2) connects to:
   - Athena in eu-west-2 for historical queries
   - Timestream in eu-west-1 for real-time metrics

## Troubleshooting

If you encounter connection issues with Timestream:

1. Verify IAM permissions allow cross-region access
2. Ensure Grafana data source is configured with the correct region (eu-west-1) for Timestream
3. Check Lambda functions have environment variable `TIMESTREAM_REGION` set to "eu-west-1"

## Cost Considerations

Using a multi-region architecture may have cost implications:

- Data transfer costs between eu-west-2 and eu-west-1
- Management overhead of resources in multiple regions
- Potential increased latency for real-time metrics

However, the benefits of having real-time metrics with Timestream typically outweigh these considerations.