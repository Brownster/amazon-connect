# ===================================================================
# AMAZON CONNECT OUTPUTS
# ===================================================================

output "connect_instance_id" {
  description = "ID of the Amazon Connect instance"
  value       = aws_connect_instance.instance.id
}

output "connect_instance_alias" {
  description = "Alias of the Amazon Connect instance"
  value       = aws_connect_instance.instance.instance_alias
}

output "connect_instance_arn" {
  description = "ARN of the Amazon Connect instance"
  value       = aws_connect_instance.instance.arn
}

output "connect_queues" {
  description = "Map of queue names to queue IDs"
  value       = { for name, queue in aws_connect_queue.queues : name => queue.id }
}

output "connect_routing_profiles" {
  description = "Map of routing profile names to profile IDs"
  value       = { for name, profile in aws_connect_routing_profile.profiles : name => profile.id }
}

output "connect_agent_passwords" {
  description = "Password for test agents (if generated randomly)"
  value       = var.create_test_agents && var.agent_password == null ? local.agent_password : null
  sensitive   = true
}

output "connect_agents" {
  description = "List of created agent usernames"
  value       = var.create_test_agents ? keys(aws_connect_user.agents) : []
}

output "connect_agent_details" {
  description = "Detailed information about created agents"
  value = var.create_test_agents ? {
    for username, agent in aws_connect_user.agents : username => {
      id              = agent.id
      arn             = agent.arn
      username        = agent.name
      first_name      = agent.identity_info[0].first_name
      last_name       = agent.identity_info[0].last_name
      email           = agent.identity_info[0].email
      routing_profile = agent.routing_profile_id
    }
  } : {}
}

output "contact_flows" {
  description = "Map of contact flow names to flow IDs"
  value       = { 
    inbound  = var.create_basic_ivr ? aws_connect_contact_flow.default_inbound[0].id : null
    outbound = var.create_basic_ivr ? aws_connect_contact_flow.default_outbound[0].id : null
    queue    = var.create_basic_ivr ? aws_connect_contact_flow.default_queue[0].id : null
    whisper  = var.create_basic_ivr ? aws_connect_contact_flow.default_whisper[0].id : null
  }
}