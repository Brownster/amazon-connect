# Generating Test CTR Data

This document explains how to generate test Contact Trace Record (CTR) data for your Amazon Connect analytics pipeline.

## Using the Python Script

1. First, make sure you have the AWS CLI configured with appropriate credentials:
   ```bash
   aws configure
   ```

2. Install the required Python dependencies:
   ```bash
   pip install boto3
   ```

3. Update the script configuration in `scripts/generate_ctr_data.py`:
   ```python
   # Configuration
   STREAM_NAME = "connect-ctr-stream"  # Your Kinesis stream name
   REGION = "eu-west-2"                # Your AWS region
   RECORD_COUNT = 100                  # Number of records to generate
   ```

4. Replace the AWS Account ID and Instance ID with your actual values:
   ```python
   "AWSAccountId": "XXXXXXXXXXXX",  # Your AWS account ID
   "InstanceId": "6e4f36f4-1b28-4725-a407-79a31c76a9b8",  # Your Connect instance ID
   ```

5. Run the script:
   ```bash
   ./scripts/generate_ctr_data.py
   ```

## Alternative Methods for Generating CTR Data

### 1. Use Amazon Connect Test Activities

If you're logged into the Amazon Connect admin console, you can generate real CTR data by:

1. Using the "Test Chat" feature in the Amazon Connect console
2. Making test phone calls using the Amazon Connect softphone
3. Creating tasks through the Connect interface

This method produces authentic CTR data but requires manual interaction.

### 2. AWS SDK for Direct Kinesis Integration

You can write a more complex program using the AWS SDK that:

1. Creates more realistic customer profiles
2. Simulates call flow paths through different queues
3. Generates more varied agent interactions

This approach is ideal for large-scale testing or performance evaluation.

### 3. AWS CloudWatch Events Scheduled Rule

For continuous data generation, create a CloudWatch Events rule that:

1. Runs on a schedule (e.g., every 5 minutes)
2. Triggers a Lambda function that generates CTR data
3. Sends the data to your Kinesis stream

This is useful for long-term testing and monitoring of your data pipeline.

## Viewing Your Data

After generating data, you can verify it's flowing through your pipeline:

1. **Kinesis Stream** - Check the monitoring tab for your stream
2. **S3 Bucket** - Look for data in your S3 bucket: `connect-ctr-data-XXXXX`
3. **Glue Database** - Run the crawler manually if needed, then check tables
4. **Athena** - Run a query like:
   ```sql
   SELECT * FROM connect_ctr_database.connect_ctr_data LIMIT 10;
   ```
5. **Grafana** - Set up dashboards using the Athena data source
