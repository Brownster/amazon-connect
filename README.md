# AWS Connect Analytics Pipeline

This project sets up a complete data pipeline for Amazon Connect CTR (Contact Trace Records) analytics using:
- Amazon Connect
- Kinesis Data Streams
- AWS Glue
- Amazon Athena
- Grafana (with Athena datasource)

## Setup Instructions

1. Generate SSH key for Grafana instance:
   ```
   ./generate_ssh_key.sh
   ```

2. Initialize and apply Terraform:
   ```
   terraform init
   terraform plan
   terraform apply
   ```

3. After deployment completes, Terraform will output:
   - Grafana server public IP
   - SSH command to connect to the Grafana instance
   - Grafana default login credentials

4. Connect to Grafana web interface:
   - Open `http://<grafana_public_ip>:3000` in your browser
   - Login with the default credentials (admin/admin)
   - You'll be prompted to change the password on first login

5. Configure Athena data source in Grafana:
   - Add a new data source and select "Amazon Athena"
   - Use the following settings:
     - Auth Provider: EC2 Instance IAM Role (same-origin)
     - Default Region: eu-west-2
     - Catalog: AwsDataCatalog
     - Database: connect_ctr_database (from Terraform output)
     - Workgroup: connect-analytics
     - Output Location: s3://connect-analytics-athena-results-xxx/output/ (from Terraform output)

6. Create dashboards to visualize your Amazon Connect data

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