# AWS Connect Analytics Pipeline

This project sets up a complete data pipeline for Amazon Connect CTR (Contact Trace Records) analytics using:
- Amazon Connect
- Kinesis Data Streams
- Kinesis Firehose
- Amazon S3
- AWS Glue
- Amazon Athena
- Grafana (with Athena datasource)

It also provides a Python script to generate test CTR data for development and testing without requiring actual Amazon Connect interactions.

## Setup Instructions

1. Generate SSH key for Grafana instance:
   ```
   ./generate_ssh_key.sh
   ```

2. Configure AWS credentials:
   ```
   export AWS_ACCESS_KEY_ID="your_access_key"
   export AWS_SECRET_ACCESS_KEY="your_secret_key"
   export AWS_REGION="eu-west-2"
   ```
   
3. Set up IAM permissions:
   - Use the provided `iam-policy-part1.json` and `iam-policy-part2.json` files to create two IAM policies
   - Attach both policies to the IAM user or role used for Terraform operations

4. Initialize and apply Terraform:
   ```
   terraform init
   terraform plan
   terraform apply
   ```

5. After deployment completes, Terraform will output:
   - Grafana server public IP
   - SSH command to connect to the Grafana instance
   - Grafana default login credentials

6. Connect to Grafana web interface:
   - Open `http://<grafana_public_ip>:3000` in your browser
   - Login with the default credentials (admin/admin)
   - You'll be prompted to change the password on first login

7. Configure Athena data source in Grafana:
   - Add a new data source and select "Amazon Athena"
   - Use the following settings:
     - Auth Provider: EC2 Instance IAM Role (same-origin)
     - Default Region: eu-west-2
     - Catalog: AwsDataCatalog
     - Database: connect_ctr_database (from Terraform output)
     - Workgroup: connect-analytics
     - Output Location: s3://connect-analytics-athena-results-xxx/output/ (from Terraform output)

8. Create dashboards to visualize your Amazon Connect data

9. Generate test CTR data:
   - See [setup_test_data.md](setup_test_data.md) for detailed instructions
   - Run the provided Python script to send test data to Kinesis:
     ```bash
     ./generate_ctr_data.py
     ```

## Architecture

```
Amazon Connect → Kinesis Data Stream → Kinesis Firehose → S3 → AWS Glue Crawler → AWS Glue Catalog
                                                                                       ↓
                                 Grafana (EC2) ← Athena plugin ← Amazon Athena
```

## Security Notes

- The EC2 instance is configured with security groups that allow inbound traffic on ports 22 (SSH) and 3000 (Grafana)
- In production, restrict these ports to specific IP ranges
- The instance is deployed in a public subnet with access to the internet
- IAM roles are configured with least privilege access to AWS services
- Due to IAM policy size limits, permissions are split into two separate policies

## Cleanup

To destroy all created resources:
```
terraform destroy
```

Note: This will delete all data in the S3 buckets and other resources created by this project.