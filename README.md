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

1. Run the initialization script to check dependencies and set up the environment:
   ```
   ./scripts/init.sh
   ```
   This script will:
   - Check for required tools (AWS CLI, Terraform, Python)
   - Install necessary Python dependencies
   - Generate SSH keys for the Grafana instance
   - Validate the Terraform configuration
   - Guide you through the remaining setup steps

2. Configure AWS credentials (if not already done):
   ```
   export AWS_ACCESS_KEY_ID="your_access_key"
   export AWS_SECRET_ACCESS_KEY="your_secret_key"
   export AWS_REGION="eu-west-2"
   ```
   Or use the AWS CLI:
   ```
   aws configure
   ```
   
3. Set up IAM permissions:
   - Use the example policies in the `iam-policies/` directory to create two IAM policies
   - See [iam-policies/README.md](iam-policies/README.md) for detailed instructions
   - Attach both policies to the IAM user or role used for Terraform operations

4. Initialize and apply Terraform:
   ```
   cd terraform
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

7. (Optional) SSH into the Grafana instance:
   - Use the SSH command from the Terraform output:
     ```
     ssh -i grafana-key ec2-user@<grafana_public_ip>
     ```
   - This gives you direct access to manage the Docker containers and configure Grafana
   - You can view logs with: `docker logs grafana`
   - You can restart Grafana with: `docker restart grafana`

8. Configure Athena data source in Grafana:
   - Detailed instructions are in [docs/grafana_athena_setup.md](docs/grafana_athena_setup.md)
   - Add a new data source and select "Amazon Athena"
   - Use the following settings:
     - Auth Provider: AWS SDK Default
     - Default Region: eu-west-2
     - Catalog: AwsDataCatalog
     - Database: connect_ctr_database (from Terraform output)
     - Workgroup: connect-analytics
     - Output Location: s3://connect-analytics-athena-results-xxx/output/ (from Terraform output)

9. Create dashboards to visualize your Amazon Connect data

10. Generate test CTR data:
   - See [docs/setup_test_data.md](docs/setup_test_data.md) for detailed instructions
   - Run the provided Python script to send test data to Kinesis:
     ```bash
     ./scripts/generate_ctr_data.py
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

## Terraform Structure

The Terraform configuration has been organized into logical modules:

- **networking**: VPC, subnets, and internet connectivity
- **connect**: Amazon Connect instance configuration
- **data_pipeline**: Kinesis, Firehose, S3, and Glue resources
- **analytics**: Athena workgroup and results storage
- **grafana**: EC2 instance with Grafana

For more details on the module structure, see [terraform/README.md](terraform/README.md).

## Cleanup

To destroy all created resources:
```
cd terraform
terraform destroy
```

Note: This will delete all data in the S3 buckets and other resources created by this project.

If you encounter permission issues during cleanup, use the provided cleanup script to manually delete resources:
```
./scripts/cleanup.sh
```