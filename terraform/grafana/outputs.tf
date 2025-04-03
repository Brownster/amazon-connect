# ===================================================================
# GRAFANA OUTPUTS
# ===================================================================

output "grafana_public_ip" {
  description = "Public IP address of the Grafana server"
  value       = aws_instance.grafana.public_ip
}

output "grafana_ssh_command" {
  description = "SSH command to connect to the Grafana instance"
  value       = "ssh -i grafana-key ec2-user@${aws_instance.grafana.public_ip}"
}

output "grafana_default_credentials" {
  description = "Default Grafana login credentials"
  value       = "Username: admin, Password: admin (you'll be prompted to change on first login)"
}