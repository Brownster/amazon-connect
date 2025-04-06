# ===================================================================
# TIMESTREAM MODULE OUTPUTS
# ===================================================================

output "timestream_database_name" {
  description = "Name of the Timestream database"
  value       = aws_timestreamwrite_database.connect_db.database_name
}

output "timestream_database_arn" {
  description = "ARN of the Timestream database"
  value       = aws_timestreamwrite_database.connect_db.arn
}

output "timestream_kms_key_arn" {
  description = "ARN of the KMS key used for Timestream encryption"
  value       = aws_kms_key.timestream_db_key.arn
}

output "timestream_kms_key_alias" {
  description = "Alias of the KMS key used for Timestream encryption"
  value       = aws_kms_alias.timestream_db_alias.name
}

output "agent_event_lambda_arn" {
  description = "ARN of the Lambda function processing agent events"
  value       = aws_lambda_function.persist_agent_event.arn
}

output "contact_event_lambda_arn" {
  description = "ARN of the Lambda function processing contact events"
  value       = aws_lambda_function.persist_contact_event.arn
}

output "instance_data_lambda_arn" {
  description = "ARN of the Lambda function processing instance data"
  value       = aws_lambda_function.persist_instance_data.arn
}

output "timestream_table_names" {
  description = "Names of the Timestream tables"
  value = {
    agent_event        = aws_timestreamwrite_table.agent_event.table_name
    agent_event_contact = aws_timestreamwrite_table.agent_event_contact.table_name
    contact_event      = aws_timestreamwrite_table.contact_event.table_name
    instance           = aws_timestreamwrite_table.instance.table_name
    queue              = aws_timestreamwrite_table.queue.table_name
    user               = aws_timestreamwrite_table.user.table_name
  }
}