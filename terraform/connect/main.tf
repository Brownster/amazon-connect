# ===================================================================
# AMAZON CONNECT CONFIGURATION
# ===================================================================
# This file defines Amazon Connect instance and related resources

# Create an Amazon Connect instance to handle customer interactions
resource "aws_connect_instance" "instance" {
  identity_management_type       = "CONNECT_MANAGED"    # Use Connect's built-in user management
  inbound_calls_enabled          = true                 # Enable inbound calls
  outbound_calls_enabled         = true                 # Enable outbound calls
  early_media_enabled            = true                 # Allow audio before call is connected
  auto_resolve_best_voices_enabled = true               # Use best voice based on caller location
  contact_flow_logs_enabled      = var.enable_contact_flow_logs  # Enable logging of contact flows
  contact_lens_enabled           = var.enable_contact_lens       # Enable Contact Lens analytics
  instance_alias                 = var.instance_alias            # Name for the Connect instance
  multi_party_conference_enabled = true                          # Enable multi-party calls
  
  tags = var.tags
}

# ===================================================================
# HOURS OF OPERATION
# ===================================================================

# Create hours of operation profiles
resource "aws_connect_hours_of_operation" "hours" {
  for_each = { for idx, h in var.hours_of_operations : h.name => h }
  
  instance_id = aws_connect_instance.instance.id
  name        = each.value.name
  description = each.value.description
  time_zone   = each.value.time_zone
  
  dynamic "config" {
    for_each = each.value.config
    content {
      day = config.value.day
      start_time {
        hours   = config.value.start_time.hours
        minutes = config.value.start_time.minutes
      }
      end_time {
        hours   = config.value.end_time.hours
        minutes = config.value.end_time.minutes
      }
    }
  }
  
  tags = var.tags
}

# ===================================================================
# QUEUES
# ===================================================================

# Create queues for different departments
resource "aws_connect_queue" "queues" {
  for_each = { for idx, q in var.queues : q.name => q }
  
  instance_id = aws_connect_instance.instance.id
  name        = each.value.name
  description = each.value.description
  hours_of_operation_id = aws_connect_hours_of_operation.hours[each.value.hours_of_operation].id
  
  tags = var.tags
  
  # Wait for hours of operation to be fully created
  depends_on = [aws_connect_hours_of_operation.hours]
}

# ===================================================================
# ROUTING PROFILES
# ===================================================================

# Create routing profiles for each department
resource "aws_connect_routing_profile" "profiles" {
  for_each = { for idx, p in var.routing_profiles : p.name => p }
  
  instance_id               = aws_connect_instance.instance.id
  name                      = each.value.name
  description               = each.value.description
  default_outbound_queue_id = aws_connect_queue.queues[each.value.default_queue].id
  
  # Create queue configurations for each queue in the profile
  dynamic "media_concurrencies" {
    for_each = toset(["VOICE", "CHAT"])
    content {
      channel     = media_concurrencies.value
      concurrency = 1
    }
  }
  
  tags = var.tags
  
  # Wait for queues to be fully created
  depends_on = [aws_connect_queue.queues]
}

# Associate queues with routing profiles
resource "aws_connect_routing_profile_queue" "queue_associations" {
  for_each = {
    for idx, profile in var.routing_profiles : 
    "${profile.name}-${idx}" => {
      profile_name = profile.name
      queue_associations = [
        for q in profile.queues : {
          queue_name = q
          priority = 1
          delay = 0
          channel = "VOICE"
        }
      ]
    }
  }
  
  instance_id = aws_connect_instance.instance.id
  routing_profile_id = aws_connect_routing_profile.profiles[each.value.profile_name].id
  
  dynamic "queue_reference" {
    for_each = each.value.queue_associations
    content {
      queue_id = aws_connect_queue.queues[queue_reference.value.queue_name].id
      channel  = queue_reference.value.channel
      priority = queue_reference.value.priority
      delay    = queue_reference.value.delay
    }
  }
  
  # Wait for routing profiles to be fully created
  depends_on = [aws_connect_routing_profile.profiles]
}

# IAM Role to allow Amazon Connect to write to the Kinesis stream
resource "aws_iam_role" "connect_kinesis" {
  name = "connect-kinesis-role"
  
  # Define which AWS services can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "connect.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy to attach to the role defining what permissions it has
resource "aws_iam_role_policy" "connect_kinesis" {
  name = "connect-kinesis-policy"
  role = aws_iam_role.connect_kinesis.id
  
  # Grant permissions to write to the Kinesis stream
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords",
          "kinesis:DescribeStream"
        ]
        Effect   = "Allow"
        Resource = var.kinesis_stream_arn
      }
    ]
  })
}

# Configure Amazon Connect to send CTR data to Kinesis stream
resource "aws_connect_instance_storage_config" "ctr_kinesis" {
  instance_id   = aws_connect_instance.instance.id
  resource_type = "CONTACT_TRACE_RECORDS"        # Specify we're configuring CTR storage
  
  storage_config {
    kinesis_stream_config {
      stream_arn = var.kinesis_stream_arn
    }
    storage_type = "KINESIS_STREAM"
  }
}

# ===================================================================
# CONTACT FLOWS AND IVR
# ===================================================================

# These are baseline contact flows needed for basic operation

# Default inbound flow
resource "aws_connect_contact_flow" "default_inbound" {
  count       = var.create_basic_ivr ? 1 : 0
  instance_id = aws_connect_instance.instance.id
  name        = "Default Inbound Flow"
  description = "Main entry point for calls with IVR menu"
  type        = "CONTACT_FLOW"
  
  # This is a simplified JSON representation of a basic IVR flow
  # In production, you'd want to export this from the Connect console or use a template
  content = jsonencode({
    "Version": "2019-10-30",
    "StartAction": "12345678-1234-1234-1234-123456789012",
    "Metadata": {
      "entryPointPosition": {"x": 20, "y": 20},
      "ActionMetadata": {
        "12345678-1234-1234-1234-123456789012": {
          "position": {"x": 20, "y": 20}
        },
        "23456789-2345-2345-2345-234567890123": {
          "position": {"x": 160, "y": 20}
        },
        "34567890-3456-3456-3456-345678901234": {
          "position": {"x": 300, "y": 20}
        }
      }
    },
    "Actions": [
      {
        "Identifier": "12345678-1234-1234-1234-123456789012",
        "Type": "PlayPrompt",
        "Parameters": {
          "Text": "Welcome to our contact center. For Sales, press 1. For Technical Support, press 2. For Customer Service, press 3."
        },
        "Transitions": {
          "NextAction": "23456789-2345-2345-2345-234567890123"
        }
      },
      {
        "Identifier": "23456789-2345-2345-2345-234567890123",
        "Type": "GetDigits",
        "Parameters": {
          "Timeout": "5"
        },
        "Transitions": {
          "NextAction": "34567890-3456-3456-3456-345678901234",
          "Conditions": [
            {
              "NextAction": "45678901-4567-4567-4567-456789012345",
              "Condition": {
                "Operator": "Equals",
                "Operands": ["1"]
              }
            },
            {
              "NextAction": "56789012-5678-5678-5678-567890123456",
              "Condition": {
                "Operator": "Equals",
                "Operands": ["2"]
              }
            },
            {
              "NextAction": "67890123-6789-6789-6789-678901234567",
              "Condition": {
                "Operator": "Equals",
                "Operands": ["3"]
              }
            }
          ]
        }
      },
      {
        "Identifier": "34567890-3456-3456-3456-345678901234",
        "Type": "PlayPrompt",
        "Parameters": {
          "Text": "Sorry, I didn't get that. Let me transfer you to customer service."
        },
        "Transitions": {
          "NextAction": "67890123-6789-6789-6789-678901234567"
        }
      },
      {
        "Identifier": "45678901-4567-4567-4567-456789012345",
        "Type": "TransferToQueue",
        "Parameters": {
          "QueueId": "$${connect:Queue:Sales}"
        },
        "Transitions": {}
      },
      {
        "Identifier": "56789012-5678-5678-5678-567890123456",
        "Type": "TransferToQueue",
        "Parameters": {
          "QueueId": "$${connect:Queue:Tech Support}"
        },
        "Transitions": {}
      },
      {
        "Identifier": "67890123-6789-6789-6789-678901234567",
        "Type": "TransferToQueue",
        "Parameters": {
          "QueueId": "$${connect:Queue:Customer Service}"
        },
        "Transitions": {}
      }
    ]
  })
  
  tags = var.tags
}

# Default outbound flow
resource "aws_connect_contact_flow" "default_outbound" {
  count       = var.create_basic_ivr ? 1 : 0
  instance_id = aws_connect_instance.instance.id
  name        = "Default Outbound Flow"
  description = "Default flow for outbound calls"
  type        = "CONTACT_FLOW"
  
  content = jsonencode({
    "Version": "2019-10-30",
    "StartAction": "12345678-1234-1234-1234-123456789012",
    "Metadata": {
      "entryPointPosition": {"x": 20, "y": 20},
      "ActionMetadata": {
        "12345678-1234-1234-1234-123456789012": {
          "position": {"x": 20, "y": 20}
        }
      }
    },
    "Actions": [
      {
        "Identifier": "12345678-1234-1234-1234-123456789012",
        "Type": "ConnectParticipant",
        "Parameters": {},
        "Transitions": {}
      }
    ]
  })
  
  tags = var.tags
}

# Default queue flow
resource "aws_connect_contact_flow" "default_queue" {
  count       = var.create_basic_ivr ? 1 : 0
  instance_id = aws_connect_instance.instance.id
  name        = "Default Queue Flow"
  description = "Default flow for queued contacts"
  type        = "QUEUE_FLOW"
  
  content = jsonencode({
    "Version": "2019-10-30",
    "StartAction": "12345678-1234-1234-1234-123456789012",
    "Metadata": {
      "entryPointPosition": {"x": 20, "y": 20},
      "ActionMetadata": {
        "12345678-1234-1234-1234-123456789012": {
          "position": {"x": 20, "y": 20}
        },
        "23456789-2345-2345-2345-234567890123": {
          "position": {"x": 160, "y": 20}
        }
      }
    },
    "Actions": [
      {
        "Identifier": "12345678-1234-1234-1234-123456789012",
        "Type": "PlayPrompt",
        "Parameters": {
          "Text": "Thank you for calling. Your call is important to us. Please wait while we connect you with the next available agent."
        },
        "Transitions": {
          "NextAction": "23456789-2345-2345-2345-234567890123"
        }
      },
      {
        "Identifier": "23456789-2345-2345-2345-234567890123",
        "Type": "Loop",
        "Parameters": {
          "LoopCount": "10"
        },
        "Transitions": {
          "NextAction": "12345678-1234-1234-1234-123456789012"
        }
      }
    ]
  })
  
  tags = var.tags
}

# Default whisper flow
resource "aws_connect_contact_flow" "default_whisper" {
  count       = var.create_basic_ivr ? 1 : 0
  instance_id = aws_connect_instance.instance.id
  name        = "Default Agent Whisper"
  description = "Default flow for agent whisper"
  type        = "AGENT_WHISPER"
  
  content = jsonencode({
    "Version": "2019-10-30",
    "StartAction": "12345678-1234-1234-1234-123456789012",
    "Metadata": {
      "entryPointPosition": {"x": 20, "y": 20},
      "ActionMetadata": {
        "12345678-1234-1234-1234-123456789012": {
          "position": {"x": 20, "y": 20}
        }
      }
    },
    "Actions": [
      {
        "Identifier": "12345678-1234-1234-1234-123456789012",
        "Type": "PlayPrompt",
        "Parameters": {
          "Text": "You are now connected with a customer."
        },
        "Transitions": {}
      }
    ]
  })
  
  tags = var.tags
}

# ===================================================================
# AGENTS
# ===================================================================

# Create random password for agents if not provided
resource "random_password" "agent_password" {
  count   = var.create_test_agents && var.agent_password == null ? 1 : 0
  length  = 12
  special = true
  override_special = "!@#$"
}

locals {
  # Use provided password or generated one
  agent_password = var.agent_password != null ? var.agent_password : try(random_password.agent_password[0].result, "")
}

# Create test users for the Connect instance (agents)
resource "aws_connect_user" "agents" {
  for_each = var.create_test_agents ? { for idx, agent in var.test_agents : agent.username => agent } : {}
  
  instance_id = aws_connect_instance.instance.id
  name        = each.value.username
  
  phone_config {
    phone_type = "SOFT_PHONE"
    auto_accept = true
  }
  
  security_profile_ids = [
    "44444444-f9e8-4123-9603-55555555aaaa"  # Basic Agent profile (this is a standard ID in Connect)
  ]
  
  # Find the right routing profile based on the agent's first group
  routing_profile_id = aws_connect_routing_profile.profiles[
    contains(each.value.groups, "Sales") ? "Sales Profile" : 
    contains(each.value.groups, "Tech Support") ? "Tech Support Profile" : 
    "Customer Service Profile"
  ].id
  
  # Set the agent's identity information
  identity_info {
    first_name = each.value.first_name
    last_name  = each.value.last_name
    email      = each.value.email
  }
  
  # Set the agent's password for Connect's built-in authentication
  password = local.agent_password
  
  tags = var.tags
  
  depends_on = [
    aws_connect_routing_profile.profiles,
    aws_connect_routing_profile_queue.queue_associations
  ]
}