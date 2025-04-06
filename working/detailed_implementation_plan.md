# Detailed Implementation Plan: AWS Connect with Timestream Integration

## 1. Overview

This implementation plan outlines the step-by-step process to enhance the current AWS Connect analytics pipeline with Amazon Timestream for real-time monitoring. We'll reuse the existing Kinesis stream for both the current S3/Athena pipeline and the new Timestream real-time monitoring components.

## 2. Architecture

```
┌─────────────────┐
│                 │
│ Amazon Connect  │
│                 │
└───────┬─────────┘
        │
        ▼
┌─────────────────┐
│                 │
│ Kinesis Stream  │◄────┐
│(connect_ctr_stream)   │
└┬────────────────┬┘    │
 │                │     │
 ▼                ▼     │
┌─────────┐    ┌────────────────┐
│         │    │                │
│Firehose │    │Lambda Function │
│         │    │(Agent Events)  │
└────┬────┘    └────────┬───────┘
     │                  │
     ▼                  ▼
┌─────────┐    ┌────────────────┐
│         │    │                │
│   S3    │    │   Timestream   │◄────┐
│         │    │                │     │
└────┬────┘    └────────────────┘     │
     │                                │
     ▼                                │
┌─────────┐    ┌────────────────┐     │
│         │    │EventBridge Rule│     │
│  Glue   │    │(Contact Events)│     │
│         │    └────────┬───────┘     │
└────┬────┘             │             │
     │                  ▼             │
     ▼            ┌────────────────┐  │
┌─────────┐       │Lambda Function │  │
│         │       │(Contact Events)│  │
│ Athena  │       └────────┬───────┘  │
│         │                │          │
└────┬────┘                └──────────┘
     │                                │
     ▼                                ▼
┌──────────────────────────────────────┐
│                                      │
│             Grafana                  │
│                                      │
└──────────────────────────────────────┘
```

## 3. Terraform Module Structure

We'll create a new `timestream` module and modify existing code to reference shared resources:

```
terraform/
├── analytics/           (existing - Athena configuration)
├── connect/             (existing - Connect configuration)
├── data_pipeline/       (existing - Kinesis, Firehose, S3, Glue)
├── grafana/             (existing - Grafana visualization)
├── networking/          (existing - VPC, subnets)
├── timestream/          (new - Timestream + Lambda functions)
│   ├── main.tf          (Timestream resources)
│   ├── variables.tf     (Timestream variables)
│   ├── outputs.tf       (Timestream outputs)
│   └── lambda_code/     (Lambda function code)
├── main.tf              (Main orchestration)
└── variables.tf         (Global variables)
```

## 4. Implementation Steps

### Step 1: Set Up Terraform Variables and Outputs

Create variables for the Timestream module in `terraform/timestream/variables.tf`:

```hcl
variable "stack_name" {
  description = "A unique name for this stack deployment, used for naming resources"
  type        = string
  default     = "connect-analytics"
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "existing_kinesis_stream_arn" {
  description = "ARN of the existing Kinesis stream for CTR data"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

variable "timestream_retention_memory" {
  description = "Timestream memory store retention in hours"
  type        = number
  default     = 25
}

variable "timestream_retention_magnetic" {
  description = "Timestream magnetic store retention in days"
  type        = number
  default     = 365
}
```

### Step 2: Create Timestream Database and Tables

Implement the Timestream resources in `terraform/timestream/main.tf`:

```hcl
# KMS Key for Timestream database encryption
resource "aws_kms_key" "timestream_db_key" {
  description             = "KMS Key for Timestream database ${var.stack_name}"
  key_usage               = "ENCRYPT_DECRYPT"
  is_enabled              = true
  enable_key_rotation     = true
  deletion_window_in_days = 7
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowGrafanaAccess"
        Effect = "Allow"
        Principal = "*"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt", 
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/grafana-instance-role"
            ]
          }
        }
      }
    ]
  })
  
  tags = var.tags
}

# KMS Alias for easier reference
resource "aws_kms_alias" "timestream_db_alias" {
  name          = "alias/TimestreamDatabaseKMSKey-${var.stack_name}"
  target_key_id = aws_kms_key.timestream_db_key.key_id
}

# Timestream Database
resource "aws_timestreamwrite_database" "connect_db" {
  database_name = var.stack_name
  kms_key_id    = aws_kms_key.timestream_db_key.arn
  
  tags = var.tags
}

# Timestream Tables
resource "aws_timestreamwrite_table" "agent_event" {
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "AgentEvent"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

resource "aws_timestreamwrite_table" "agent_event_contact" {
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "AgentEvent_Contact"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

resource "aws_timestreamwrite_table" "contact_event" {
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "ContactEvent"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

resource "aws_timestreamwrite_table" "instance" {
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "Instance"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

resource "aws_timestreamwrite_table" "queue" {
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "Queue"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

resource "aws_timestreamwrite_table" "user" {
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "User"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}
```

### Step 3: Create IAM Policies for Timestream Access

Add to `terraform/timestream/main.tf`:

```hcl
# IAM Policy for Timestream Service Access
resource "aws_iam_policy" "timestream_service_access" {
  name        = "${var.stack_name}-TimestreamServiceAccess"
  path        = "/"
  description = "Allows Lambda functions to describe Timestream endpoints"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "TimestreamDescribeEndpoints",
        Effect   = "Allow",
        Action   = "timestream:DescribeEndpoints",
        Resource = "*"
      }
    ]
  })
  
  tags = var.tags
}

# IAM Policy for Timestream Table Write Access
resource "aws_iam_policy" "timestream_table_access" {
  name        = "${var.stack_name}-TimestreamTableAccess"
  path        = "/"
  description = "Allows Lambda functions to write to Timestream tables"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "TimestreamTableWrite",
        Effect   = "Allow",
        Action   = "timestream:WriteRecords",
        Resource = "arn:aws:timestream:${var.aws_region}:${data.aws_caller_identity.current.account_id}:database/${aws_timestreamwrite_database.connect_db.database_name}/table/*"
      },
      {
        Sid      = "TimestreamKMSAccess",
        Effect   = "Allow",
        Action   = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = aws_kms_key.timestream_db_key.arn
      }
    ]
  })
  
  tags = var.tags
}
```

### Step 4: Create Lambda Functions for Event Processing

Add to `terraform/timestream/main.tf`:

```hcl
# Lambda function to process agent events from Kinesis
resource "aws_lambda_function" "persist_agent_event" {
  function_name = "${var.stack_name}-Persist-AgentEvent"
  role          = aws_iam_role.persist_agent_event_lambda.arn
  handler       = "persist_agent_event.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300
  memory_size   = 256
  
  filename         = data.archive_file.persist_agent_event_zip.output_path
  source_code_hash = data.archive_file.persist_agent_event_zip.output_base64sha256
  
  environment {
    variables = {
      TIMESTREAM_DATABASE_NAME = aws_timestreamwrite_database.connect_db.database_name
      TIMESTREAM_REGION        = var.aws_region
    }
  }
  
  tags = var.tags
}

# Lambda event source mapping for Kinesis stream
resource "aws_lambda_event_source_mapping" "kinesis_agent_event_mapping" {
  event_source_arn          = var.existing_kinesis_stream_arn
  function_name             = aws_lambda_function.persist_agent_event.arn
  starting_position         = "LATEST"
  batch_size                = 100
  maximum_batching_window_in_seconds = 5
  parallelization_factor    = 10
  maximum_retry_attempts    = 3
  enabled                   = true
}

# Lambda function to process contact events from EventBridge
resource "aws_lambda_function" "persist_contact_event" {
  function_name = "${var.stack_name}-Persist-ContactEvent"
  role          = aws_iam_role.persist_contact_event_lambda.arn
  handler       = "persist_contact_event.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300
  memory_size   = 256
  
  filename         = data.archive_file.persist_contact_event_zip.output_path
  source_code_hash = data.archive_file.persist_contact_event_zip.output_base64sha256
  
  environment {
    variables = {
      TIMESTREAM_DATABASE_NAME = aws_timestreamwrite_database.connect_db.database_name
      TIMESTREAM_REGION        = var.aws_region
    }
  }
  
  tags = var.tags
}

# EventBridge rule for Amazon Connect contact events
resource "aws_cloudwatch_event_rule" "persist_contact_event" {
  name        = "${var.stack_name}-PersistContactEvent"
  description = "Capture Amazon Connect Contact Events"
  
  event_pattern = jsonencode({
    source = ["aws.connect"],
    "detail-type" = ["Amazon Connect Contact Event"]
  })
  
  tags = var.tags
}

# EventBridge target for contact events
resource "aws_cloudwatch_event_target" "persist_contact_event_lambda" {
  rule      = aws_cloudwatch_event_rule.persist_contact_event.name
  target_id = "${var.stack_name}-ContactEventTarget"
  arn       = aws_lambda_function.persist_contact_event.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_contact_event" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.persist_contact_event.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.persist_contact_event.arn
}

# Lambda function to periodically collect instance data
resource "aws_lambda_function" "persist_instance_data" {
  function_name = "${var.stack_name}-Persist-InstanceData"
  role          = aws_iam_role.persist_instance_data_lambda.arn
  handler       = "persist_instance_data.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300
  memory_size   = 256
  
  filename         = data.archive_file.persist_instance_data_zip.output_path
  source_code_hash = data.archive_file.persist_instance_data_zip.output_base64sha256
  
  environment {
    variables = {
      TIMESTREAM_DATABASE_NAME = aws_timestreamwrite_database.connect_db.database_name
      TIMESTREAM_REGION        = var.aws_region
    }
  }
  
  tags = var.tags
}

# EventBridge scheduler for instance data collection
resource "aws_scheduler_schedule" "persist_instance_data" {
  name       = "${var.stack_name}-InstanceDataSchedule"
  group_name = "default"
  
  flexible_time_window {
    mode = "OFF"
  }
  
  schedule_expression = "rate(5 minutes)"
  
  target {
    arn      = aws_lambda_function.persist_instance_data.arn
    role_arn = aws_iam_role.persist_instance_data_schedule.arn
  }
}
```

### Step 5: Modify Grafana Module to Support Timestream

Add Timestream datasource configuration to the Grafana EC2 instance:

1. Update `terraform/grafana/main.tf`:

```hcl
# IAM Policy for Grafana to access Timestream
resource "aws_iam_role_policy" "grafana_timestream" {
  name = "grafana-timestream-policy"
  role = aws_iam_role.grafana_instance.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "timestream:DescribeEndpoints",
          "timestream:SelectValues",
          "timestream:CancelQuery",
          "timestream:ListDatabases",
          "timestream:ListTables",
          "timestream:ListMeasures",
          "timestream:DescribeDatabase",
          "timestream:DescribeTable"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = var.timestream_kms_key_arn
      }
    ]
  })
}
```

2. Update the Grafana environment variables:

```hcl
# In the Docker Compose file (terraform/grafana/main.tf), add Timestream plugin
environment:
  - GF_INSTALL_PLUGINS=grafana-athena-datasource,grafana-prometheus-datasource,grafana-timestream-datasource
```

3. Add Timestream datasource configuration:

```hcl
# Configure Timestream datasource in Grafana
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Timestream",
    "type": "grafana-timestream-datasource",
    "jsonData": {
      "authType": "default",
      "defaultRegion": "${var.aws_region}"
    },
    "access": "proxy",
    "isDefault": false
  }'
```

### Step 6: Create Main Module Integration

Update `terraform/main.tf` to integrate the new Timestream module:

```hcl
module "timestream" {
  source = "./terraform/timestream"
  
  stack_name               = var.project_name
  aws_region               = var.aws_region
  existing_kinesis_stream_arn = module.data_pipeline.kinesis_stream_arn
  tags                     = var.tags
  
  # Depends on the data pipeline to ensure Kinesis stream exists
  depends_on = [module.data_pipeline]
}

# Update Grafana module to pass Timestream information
module "grafana" {
  source = "./terraform/grafana"
  
  # Existing parameters...
  
  # Add Timestream parameters
  timestream_database_name = module.timestream.timestream_database_name
  timestream_database_arn  = module.timestream.timestream_database_arn
  timestream_kms_key_arn   = module.timestream.timestream_kms_key_arn
}
```

### Step 7: Implement Lambda Function Code

Create the Lambda function code in `terraform/timestream/lambda_code/`:

1. `persist_agent_event.py` - Processes agent events from Kinesis
2. `persist_contact_event.py` - Processes contact events from EventBridge
3. `persist_instance_data.py` - Collects instance, queue, and user data periodically

### Step 8: Create Grafana Dashboards

Create dashboard JSON files to be loaded into Grafana:

1. Real-time agent status dashboard using Timestream
2. Real-time contact flow dashboard using Timestream
3. Historical analytics dashboard using Athena

## 5. Testing and Validation

1. Deploy the infrastructure and verify all resources are created
2. Validate Timestream database and table creation
3. Generate test events and verify data flow:
   - Use the connect_ctr_stream Kinesis stream to send test data
   - Verify data is received in both S3 (via Firehose) and Timestream (via Lambda)
4. Verify Grafana can access both Athena and Timestream data sources
5. Test dashboards to ensure they display data correctly

## 6. Considerations and Best Practices

1. **Cost Management**:
   - Timestream pricing is based on data ingestion, storage, and querying
   - Configure appropriate retention periods to balance cost and performance
   - Use write batching in Lambda functions to reduce API costs

2. **Performance**:
   - Lambda batching parameters are critical for performance
   - Timestream query optimizations should be applied in Grafana panels

3. **Monitoring**:
   - Add CloudWatch alarms for Lambda errors and Timestream throttling
   - Monitor Kinesis stream throughput to ensure it's not causing backpressure

4. **Security**:
   - Use IAM roles with least privilege principle
   - Encrypt data at rest and in transit
   - Regularly rotate KMS keys

## 7. Future Enhancements

1. Add multi-region support for Timestream
2. Implement alerting based on real-time metrics
3. Add machine learning for anomaly detection
4. Create custom Grafana plugins for Connect-specific visualizations

## 8. Next Steps

1. Complete the implementation of the Terraform modules
2. Implement the Lambda function code
3. Create Grafana dashboards
4. Test the end-to-end solution
5. Document operational procedures