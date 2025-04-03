# Scripts

This directory contains utility scripts for the AWS Connect Analytics Pipeline project.

## Files

- **generate_ssh_key.sh** - Creates SSH keys for the Grafana EC2 instance
- **generate_ctr_data.py** - Generates test Contact Trace Records (CTR) for the pipeline
- **cleanup.sh** - Helps with manual resource cleanup if Terraform destroy fails
- **init.sh** - Initializes the project environment

## Test Data Generation

The `generate_ctr_data.py` script creates synthetic CTR data and sends it to the Kinesis stream configured in the Terraform project. The script:

1. Validates that the Kinesis stream exists
2. Generates realistic Contact Trace Records
3. Sends data in batches to avoid throttling
4. Outputs next steps for the analytics pipeline

### S3 Data Partitioning

The data is stored in S3 with an optimized partitioning structure:
```
connect-ctr-data/
├── year=YYYY/
│   └── month=MM/
│       └── day=DD/
│           └── hour=HH/
│               └── data files
```

This partitioning:
- Improves query performance in Athena
- Reduces cost by scanning less data
- Makes it easier to manage retention periods

### Usage

Run the script from the project root directory after applying the Terraform configuration:

```bash
# First make sure the Terraform resources are created
cd terraform
terraform apply

# Then generate test data
cd ..
python3 scripts/generate_ctr_data.py
```

You can customize the script by editing these variables:
- `STREAM_NAME`: Name of your Kinesis stream
- `REGION`: AWS region 
- `RECORD_COUNT`: Number of test records to generate
- `BATCH_SIZE`: Records per batch to avoid throttling

See the main README.md file or the documentation in the `docs/` directory for more details on using these scripts.