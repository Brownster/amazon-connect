# ===================================================================
# AMAZON CONNECT OUTPUTS
# ===================================================================

output "connect_instance_id" {
  description = "ID of the Amazon Connect instance"
  value       = aws_connect_instance.instance.id
}