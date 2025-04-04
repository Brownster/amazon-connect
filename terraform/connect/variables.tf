# ===================================================================
# AMAZON CONNECT VARIABLES
# ===================================================================

variable "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream for Contact Trace Records"
  type        = string
}

variable "instance_alias" {
  description = "Alias for the Amazon Connect instance"
  type        = string
  default     = "thebrowns"
}

variable "enable_contact_lens" {
  description = "Whether to enable Contact Lens analytics"
  type        = bool
  default     = true
}

variable "enable_contact_flow_logs" {
  description = "Whether to enable Contact Flow logs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to Connect resources"
  type        = map(string)
  default     = {}
}

# Agent variables
variable "create_test_agents" {
  description = "Whether to create test agents for the Connect instance"
  type        = bool
  default     = true
}

variable "agent_password" {
  description = "Password for test agents (if null, a random password will be generated)"
  type        = string
  default     = null
  sensitive   = true
}

variable "test_agents" {
  description = "List of test agents to create"
  type = list(object({
    username    = string
    first_name  = string
    last_name   = string
    email       = string
    phone       = string
    groups      = list(string)
  }))
  default = [
    {
      username    = "agent.sales1"
      first_name  = "Alex"
      last_name   = "Johnson"
      email       = "alex.johnson@example.com"
      phone       = "+442071234567"
      groups      = ["Sales"]
    },
    {
      username    = "agent.sales2"
      first_name  = "Jamie"
      last_name   = "Smith"
      email       = "jamie.smith@example.com"
      phone       = "+442071234568"
      groups      = ["Sales"]
    },
    {
      username    = "agent.tech1"
      first_name  = "Casey"
      last_name   = "Brown"
      email       = "casey.brown@example.com"
      phone       = "+442071234569"
      groups      = ["Tech Support"]
    },
    {
      username    = "agent.tech2"
      first_name  = "Morgan"
      last_name   = "Lee"
      email       = "morgan.lee@example.com"
      phone       = "+442071234570"
      groups      = ["Tech Support"]
    },
    {
      username    = "agent.service1"
      first_name  = "Taylor"
      last_name   = "Wilson"
      email       = "taylor.wilson@example.com"
      phone       = "+442071234571"
      groups      = ["Customer Service"]
    },
    {
      username    = "agent.service2"
      first_name  = "Sam"
      last_name   = "Davis"
      email       = "sam.davis@example.com"
      phone       = "+442071234572"
      groups      = ["Customer Service"]
    }
  ]
}

# Routing variables
variable "routing_profiles" {
  description = "List of routing profiles to create"
  type = list(object({
    name        = string
    description = string
    queues      = list(string)
    default_queue = string
  }))
  default = [
    {
      name        = "Sales Profile"
      description = "Routing profile for Sales agents"
      queues      = ["Sales"]
      default_queue = "Sales"
    },
    {
      name        = "Tech Support Profile"
      description = "Routing profile for Tech Support agents"
      queues      = ["Tech Support"]
      default_queue = "Tech Support"
    },
    {
      name        = "Customer Service Profile"
      description = "Routing profile for Customer Service agents"
      queues      = ["Customer Service"]
      default_queue = "Customer Service"
    },
    {
      name        = "Admin Profile"
      description = "Routing profile for admins with access to all queues"
      queues      = ["Sales", "Tech Support", "Customer Service"]
      default_queue = "Customer Service"
    }
  ]
}

# Queue variables
variable "queues" {
  description = "List of queues to create"
  type = list(object({
    name        = string
    description = string
    hours_of_operation = string
  }))
  default = [
    {
      name        = "Sales"
      description = "Queue for sales inquiries"
      hours_of_operation = "Business Hours"
    },
    {
      name        = "Tech Support"
      description = "Queue for technical support"
      hours_of_operation = "24/7"
    },
    {
      name        = "Customer Service"
      description = "Queue for general customer service"
      hours_of_operation = "Business Hours"
    }
  ]
}

# Hours of operation variables
variable "hours_of_operations" {
  description = "List of hours of operation profiles to create"
  type = list(object({
    name        = string
    description = string
    time_zone   = string
    config = list(object({
      day       = string
      start_time = object({
        hours   = number
        minutes = number
      })
      end_time = object({
        hours   = number
        minutes = number
      })
    }))
  }))
  default = [
    {
      name        = "Business Hours"
      description = "Monday to Friday, 9am to 5pm"
      time_zone   = "Europe/London"
      config = [
        {
          day = "MONDAY"
          start_time = {
            hours   = 9
            minutes = 0
          }
          end_time = {
            hours   = 17
            minutes = 0
          }
        },
        {
          day = "TUESDAY"
          start_time = {
            hours   = 9
            minutes = 0
          }
          end_time = {
            hours   = 17
            minutes = 0
          }
        },
        {
          day = "WEDNESDAY"
          start_time = {
            hours   = 9
            minutes = 0
          }
          end_time = {
            hours   = 17
            minutes = 0
          }
        },
        {
          day = "THURSDAY"
          start_time = {
            hours   = 9
            minutes = 0
          }
          end_time = {
            hours   = 17
            minutes = 0
          }
        },
        {
          day = "FRIDAY"
          start_time = {
            hours   = 9
            minutes = 0
          }
          end_time = {
            hours   = 17
            minutes = 0
          }
        }
      ]
    },
    {
      name        = "24/7"
      description = "24 hours a day, 7 days a week"
      time_zone   = "Europe/London"
      config = [
        {
          day = "MONDAY"
          start_time = {
            hours   = 0
            minutes = 0
          }
          end_time = {
            hours   = 23
            minutes = 59
          }
        },
        {
          day = "TUESDAY"
          start_time = {
            hours   = 0
            minutes = 0
          }
          end_time = {
            hours   = 23
            minutes = 59
          }
        },
        {
          day = "WEDNESDAY"
          start_time = {
            hours   = 0
            minutes = 0
          }
          end_time = {
            hours   = 23
            minutes = 59
          }
        },
        {
          day = "THURSDAY"
          start_time = {
            hours   = 0
            minutes = 0
          }
          end_time = {
            hours   = 23
            minutes = 59
          }
        },
        {
          day = "FRIDAY"
          start_time = {
            hours   = 0
            minutes = 0
          }
          end_time = {
            hours   = 23
            minutes = 59
          }
        },
        {
          day = "SATURDAY"
          start_time = {
            hours   = 0
            minutes = 0
          }
          end_time = {
            hours   = 23
            minutes = 59
          }
        },
        {
          day = "SUNDAY"
          start_time = {
            hours   = 0
            minutes = 0
          }
          end_time = {
            hours   = 23
            minutes = 59
          }
        }
      ]
    }
  ]
}

# IVR and Contact Flow variables
variable "create_basic_ivr" {
  description = "Whether to create a basic IVR flow"
  type        = bool
  default     = true
}