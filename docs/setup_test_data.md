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
   BATCH_SIZE = 25                     # Records per batch
   DELAY_BETWEEN_BATCHES = 1           # Seconds between batches
   VALIDATE_STREAM = True              # Validate stream exists before sending
   ```

4. Replace the AWS Account ID and Instance ID with your actual values:
   ```python
   "AWSAccountId": "XXXXXXXXXXXX",  # Your AWS account ID
   "InstanceId": "6e4f36f4-1b28-4725-a407-79a31c76a9b8",  # Your Connect instance ID
   ```

5. Run the script:
   ```bash
   python3 ./scripts/generate_ctr_data.py
   ```

The script now includes:
- Resource validation to ensure the Kinesis stream exists
- Improved error handling and user guidance
- Batch processing to avoid throttling
- Clear next steps after data generation completes

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

## S3 Data Partitioning

The CTR data is now stored in S3 using an optimized time-based partitioning structure:

```
connect-ctr-data/
├── year=2023/
│   └── month=12/
│       └── day=15/
│           └── hour=14/
│               └── data files
```

### Benefits of Partitioning

1. **Improved Query Performance**
   - Athena can skip irrelevant partitions, reading only the data you need
   - Partition pruning happens automatically with WHERE clauses on date/time

2. **Cost Reduction**
   - Pay only for the data you scan in Athena
   - Time-based queries scan significantly less data

3. **Better Data Management**
   - Easier to implement retention policies
   - Clearer organization of historical data

### Error Handling

Error data is also partitioned and stored separately:
```
connect-ctr-data-errors/ErrorType/year=YYYY/month=MM/day=DD/hour=HH/
```

This makes it easier to diagnose issues when they occur.

## Viewing Your Data

After generating data, you can verify it's flowing through your pipeline:

1. **Kinesis Stream** - Check the monitoring tab for your stream
2. **S3 Bucket** - Look for data in your S3 bucket with the time-based partitioning: 
   ```
   connect-ctr-data-XXXXX/year=2023/month=12/day=15/hour=14/
   ```
3. **Glue Database** - Run the crawler manually if needed, then check tables
4. **Athena** - Run a query like:
   ```sql
   -- Simple query to fetch all data
   SELECT * FROM connect_ctr_database.connect_ctr_data LIMIT 10;
   
   -- Query leveraging partitions (much more efficient)
   SELECT * FROM connect_ctr_database.connect_ctr_data 
   WHERE year='2023' AND month='12' AND day='15' 
   LIMIT 10;
   ```
5. **Grafana** - Set up dashboards using the Athena data source with time-based filters
