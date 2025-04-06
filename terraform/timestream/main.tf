# ===================================================================
# TIMESTREAM MODULE - MAIN CONFIGURATION
# ===================================================================
# This file defines Amazon Timestream resources and related Lambda functions
# for real-time monitoring of Amazon Connect data

# Define the AWS provider for Timestream resources (defaults to eu-west-1)
provider "aws" {
  alias  = "timestream"
  region = var.timestream_region  # Must be a region where Timestream is available
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {
  provider = aws.timestream
}

# Archive files for Lambda functions
data "archive_file" "persist_agent_event_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_code/persist_agent_event.py"
  output_path = "${path.module}/lambda_code/persist_agent_event.zip"
}

data "archive_file" "persist_contact_event_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_code/persist_contact_event.py"
  output_path = "${path.module}/lambda_code/persist_contact_event.zip"
}

data "archive_file" "persist_instance_data_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_code/persist_instance_data.py"
  output_path = "${path.module}/lambda_code/persist_instance_data.zip"
}

# ===================================================================
# TIMESTREAM RESOURCES
# ===================================================================

# KMS Key for Timestream database encryption
resource "aws_kms_key" "timestream_db_key" {
  provider                = aws.timestream
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
        Principal = {
          AWS = "*"
        }
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
  provider      = aws.timestream
  name          = "alias/TimestreamDatabaseKMSKey-${var.stack_name}"
  target_key_id = aws_kms_key.timestream_db_key.key_id
}

# Timestream Database
resource "aws_timestreamwrite_database" "connect_db" {
  provider      = aws.timestream
  database_name = var.stack_name
  kms_key_id    = aws_kms_key.timestream_db_key.arn
  
  tags = {
    Project = "ConnectAnalytics"
    Module  = "Timestream"
  }
}

# Timestream Tables
resource "aws_timestreamwrite_table" "agent_event" {
  provider      = aws.timestream
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "AgentEvent"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = {
    Project = "ConnectAnalytics"
    Module  = "Timestream"
    Table   = "AgentEvent"
  }
}

resource "aws_timestreamwrite_table" "agent_event_contact" {
  provider      = aws.timestream
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "AgentEvent_Contact"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

resource "aws_timestreamwrite_table" "contact_event" {
  provider      = aws.timestream
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "ContactEvent"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

resource "aws_timestreamwrite_table" "instance" {
  provider      = aws.timestream
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "Instance"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

resource "aws_timestreamwrite_table" "queue" {
  provider      = aws.timestream
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "Queue"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

resource "aws_timestreamwrite_table" "user" {
  provider      = aws.timestream
  database_name = aws_timestreamwrite_database.connect_db.database_name
  table_name    = "User"
  
  retention_properties {
    memory_store_retention_period_in_hours = var.timestream_retention_memory
    magnetic_store_retention_period_in_days = var.timestream_retention_magnetic
  }
  
  tags = var.tags
}

# ===================================================================
# IAM POLICIES AND ROLES
# ===================================================================

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
        Resource = "${aws_timestreamwrite_database.connect_db.arn}/table/*"
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

# IAM Policy for Kinesis access
resource "aws_iam_policy" "kinesis_read_access" {
  name        = "${var.stack_name}-KinesisReadAccess"
  path        = "/"
  description = "Allows Lambda to read from the Connect Kinesis stream"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:DescribeStream",
          "kinesis:ListShards"
        ],
        Resource = var.existing_kinesis_stream_arn
      },
      {
        Effect = "Allow",
        Action = [
          "kinesis:ListStreams"
        ],
        Resource = "*"
      }
    ]
  })
  
  tags = var.tags
}

# IAM Role for Agent Event Lambda
resource "aws_iam_role" "persist_agent_event_lambda" {
  name = "${var.stack_name}-PersistAgentEvent-Role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Basic Lambda execution policy for Agent Event Lambda
resource "aws_iam_policy" "agent_event_lambda_basic" {
  name        = "${var.stack_name}-AgentEventLambdaBasic"
  path        = "/"
  description = "Basic Lambda execution policy for Agent Event Lambda"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.stack_name}-Persist-AgentEvent:*"
        ]
      }
    ]
  })
  
  tags = var.tags
}

# Attach policies to Agent Event Lambda role
resource "aws_iam_role_policy_attachment" "agent_event_lambda_basic" {
  role       = aws_iam_role.persist_agent_event_lambda.name
  policy_arn = aws_iam_policy.agent_event_lambda_basic.arn
}

resource "aws_iam_role_policy_attachment" "agent_event_lambda_timestream" {
  role       = aws_iam_role.persist_agent_event_lambda.name
  policy_arn = aws_iam_policy.timestream_service_access.arn
}

resource "aws_iam_role_policy_attachment" "agent_event_lambda_timestream_write" {
  role       = aws_iam_role.persist_agent_event_lambda.name
  policy_arn = aws_iam_policy.timestream_table_access.arn
}

resource "aws_iam_role_policy_attachment" "agent_event_lambda_kinesis" {
  role       = aws_iam_role.persist_agent_event_lambda.name
  policy_arn = aws_iam_policy.kinesis_read_access.arn
}

# IAM Role for Contact Event Lambda
resource "aws_iam_role" "persist_contact_event_lambda" {
  name = "${var.stack_name}-PersistContactEvent-Role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Basic Lambda execution policy for Contact Event Lambda
resource "aws_iam_policy" "contact_event_lambda_basic" {
  name        = "${var.stack_name}-ContactEventLambdaBasic"
  path        = "/"
  description = "Basic Lambda execution policy for Contact Event Lambda"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.stack_name}-Persist-ContactEvent:*"
        ]
      }
    ]
  })
  
  tags = var.tags
}

# Attach policies to Contact Event Lambda role
resource "aws_iam_role_policy_attachment" "contact_event_lambda_basic" {
  role       = aws_iam_role.persist_contact_event_lambda.name
  policy_arn = aws_iam_policy.contact_event_lambda_basic.arn
}

resource "aws_iam_role_policy_attachment" "contact_event_lambda_timestream" {
  role       = aws_iam_role.persist_contact_event_lambda.name
  policy_arn = aws_iam_policy.timestream_service_access.arn
}

resource "aws_iam_role_policy_attachment" "contact_event_lambda_timestream_write" {
  role       = aws_iam_role.persist_contact_event_lambda.name
  policy_arn = aws_iam_policy.timestream_table_access.arn
}

# IAM Role for Instance Data Lambda
resource "aws_iam_role" "persist_instance_data_lambda" {
  name = "${var.stack_name}-PersistInstanceData-Role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Basic Lambda execution policy for Instance Data Lambda
resource "aws_iam_policy" "instance_data_lambda_basic" {
  name        = "${var.stack_name}-InstanceDataLambdaBasic"
  path        = "/"
  description = "Basic Lambda execution policy for Instance Data Lambda"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.stack_name}-Persist-InstanceData:*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "connect:ListInstances",
          "connect:DescribeInstance",
          "connect:ListQueues",
          "connect:DescribeQueue",
          "connect:ListUsers",
          "connect:DescribeUser"
        ],
        Resource = "*"
      }
    ]
  })
  
  tags = var.tags
}

# Attach policies to Instance Data Lambda role
resource "aws_iam_role_policy_attachment" "instance_data_lambda_basic" {
  role       = aws_iam_role.persist_instance_data_lambda.name
  policy_arn = aws_iam_policy.instance_data_lambda_basic.arn
}

resource "aws_iam_role_policy_attachment" "instance_data_lambda_timestream" {
  role       = aws_iam_role.persist_instance_data_lambda.name
  policy_arn = aws_iam_policy.timestream_service_access.arn
}

resource "aws_iam_role_policy_attachment" "instance_data_lambda_timestream_write" {
  role       = aws_iam_role.persist_instance_data_lambda.name
  policy_arn = aws_iam_policy.timestream_table_access.arn
}

# IAM Role for EventBridge scheduler to invoke Lambda
resource "aws_iam_role" "scheduler_role" {
  name = "${var.stack_name}-SchedulerRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# IAM Policy for scheduler to invoke Lambda
resource "aws_iam_policy" "scheduler_invoke_lambda" {
  name        = "${var.stack_name}-SchedulerInvokeLambda"
  path        = "/"
  description = "Allows EventBridge scheduler to invoke Lambda"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "lambda:InvokeFunction"
        ],
        Resource = [
          "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.stack_name}-Persist-InstanceData"
        ]
      }
    ]
  })
  
  tags = var.tags
}

# Attach policy to scheduler role
resource "aws_iam_role_policy_attachment" "scheduler_invoke_lambda" {
  role       = aws_iam_role.scheduler_role.name
  policy_arn = aws_iam_policy.scheduler_invoke_lambda.arn
}

# ===================================================================
# LAMBDA FUNCTIONS
# ===================================================================

# Lambda function to process agent events from Kinesis
resource "aws_lambda_function" "persist_agent_event" {
  function_name = "${var.stack_name}-Persist-AgentEvent"
  role          = aws_iam_role.persist_agent_event_lambda.arn
  handler       = "persist_agent_event.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  
  filename         = data.archive_file.persist_agent_event_zip.output_path
  source_code_hash = data.archive_file.persist_agent_event_zip.output_base64sha256
  
  environment {
    variables = {
      TIMESTREAM_DATABASE_NAME = aws_timestreamwrite_database.connect_db.database_name
      TIMESTREAM_REGION        = var.timestream_region
    }
  }
  
  tags = var.tags
}

# Lambda event source mapping for Kinesis stream
resource "aws_lambda_event_source_mapping" "kinesis_agent_event_mapping" {
  event_source_arn          = var.existing_kinesis_stream_arn
  function_name             = aws_lambda_function.persist_agent_event.arn
  starting_position         = "LATEST"
  batch_size                = var.kinesis_batch_size
  maximum_batching_window_in_seconds = var.kinesis_batch_window
  parallelization_factor    = 10
  maximum_retry_attempts    = 3
  enabled                   = true
  
  depends_on = [
    aws_lambda_function.persist_agent_event,
    aws_iam_role_policy_attachment.agent_event_lambda_kinesis
  ]
}

# Lambda function to process contact events from EventBridge
resource "aws_lambda_function" "persist_contact_event" {
  function_name = "${var.stack_name}-Persist-ContactEvent"
  role          = aws_iam_role.persist_contact_event_lambda.arn
  handler       = "persist_contact_event.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  
  filename         = data.archive_file.persist_contact_event_zip.output_path
  source_code_hash = data.archive_file.persist_contact_event_zip.output_base64sha256
  
  environment {
    variables = {
      TIMESTREAM_DATABASE_NAME = aws_timestreamwrite_database.connect_db.database_name
      TIMESTREAM_REGION        = var.timestream_region
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
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  
  filename         = data.archive_file.persist_instance_data_zip.output_path
  source_code_hash = data.archive_file.persist_instance_data_zip.output_base64sha256
  
  environment {
    variables = {
      TIMESTREAM_DATABASE_NAME = aws_timestreamwrite_database.connect_db.database_name
      TIMESTREAM_REGION        = var.timestream_region
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
  
  schedule_expression = var.instance_data_schedule
  
  target {
    arn      = aws_lambda_function.persist_instance_data.arn
    role_arn = aws_iam_role.scheduler_role.arn
  }
  
  depends_on = [
    aws_lambda_function.persist_instance_data,
    aws_iam_role_policy_attachment.scheduler_invoke_lambda
  ]
}