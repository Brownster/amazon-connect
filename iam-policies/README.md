# IAM Policies

This directory contains example IAM policies required for deploying and managing the AWS Connect Analytics Pipeline.

## Policy Files

The IAM policy has been split into two parts due to AWS IAM policy size limits (maximum 6144 characters):

- **example-policy-part1.json** - Contains permissions for Amazon Connect, EC2, VPC, S3, and IAM role management
- **example-policy-part2.json** - Contains permissions for Kinesis, Firehose, Glue, Athena, and CloudWatch

## Usage

1. Create two IAM policies in your AWS account using these example files
2. Attach both policies to the IAM user or role that will be used to run Terraform

## Implementation Notes

- These policies follow the principle of least privilege, granting only the permissions required for this project
- Resource ARNs use wildcards (`*`) where appropriate to allow for dynamic resource naming
- Explicit resource ARNs are used where known, such as for IAM roles and specific stream names
- The policies include permissions for both creating and destroying all resources managed by this project

## Important Permissions

Some key permissions to note:

- `connect:*` - Allows full access to Amazon Connect resources
- `iam:PassRole` - Required for services to assume specific IAM roles
- `glue:GetTags` - Required when deleting Glue database resources
- Various S3 permissions - Required for both data storage and Athena query results