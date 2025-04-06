# Timestream Multi-Region Solution

## Problem
The Amazon Connect analytics stack encountered the following issues:
1. Timestream service is not available in `eu-west-2` (London) region
2. The stack was trying to create resources in both regions but had configuration issues
3. Tag validation errors with Timestream resources
4. Permission issues with KMS and Timestream services

## Solution
We've implemented a multi-region approach:
1. Most resources (Amazon Connect, Kinesis, S3, etc.) in `eu-west-2` (London)
2. Timestream resources in `eu-west-1` (Ireland) where it's supported

## Resources Created

### In eu-west-1 (Ireland)
- Timestream Database: `connect-analytics-ts-9ef29e46`
- Timestream Tables: 
  - `AgentEvents`
  - `ContactEvents`

### In eu-west-2 (London)
- Amazon Connect instance: `thebrowns-c4ezxzvi`
- Kinesis stream: `connect-ctr-stream-c4ezxzvi`
- S3 buckets: 
  - `connect-ctr-data-c4ezxzvi`
  - `connect-analytics-athena-results-c4ezxzvi`
- IAM roles with appropriate permissions
- Grafana EC2 instance (with Timestream configured)

## How to Use This Configuration

### Connecting Grafana to Timestream
1. SSH into the Grafana instance: `ssh -i grafana-key ec2-user@3.10.180.59`
2. Access Grafana web interface: `http://3.10.180.59:3000`
3. Timestream datasource is configured to point to:
   - Region: `eu-west-1`
   - Database: `connect-analytics-ts-9ef29e46`

### Monitoring CTR Data
1. Data flows: Connect CTR → Kinesis → S3 → Athena (for historical data)
2. For real-time monitoring: Connect CTR → Kinesis → Lambda → Timestream → Grafana

## Troubleshooting
If you encounter issues with the Timestream integration:
1. Ensure your IAM user has permissions to access Timestream and KMS in `eu-west-1`
2. Check that Grafana is correctly configured to access Timestream in `eu-west-1`
3. Verify that the Lambda functions have appropriate permissions to write to Timestream

## Scripts Created
1. `setup_timestream_permissions.sh` - Add appropriate Timestream permissions
2. `add_kms_permissions.sh` - Add KMS permissions for encryption
3. `fix_timestream_module.sh` - Apply a standalone Timestream configuration