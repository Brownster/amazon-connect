# Amazon Connect Setup Guide

This document explains how to use the expanded Amazon Connect module to quickly set up a functional contact center with agents, queues, routing profiles, and a basic IVR flow.

## Overview

The Amazon Connect module sets up a complete contact center environment with:

- An Amazon Connect instance
- Pre-configured hours of operation (Business Hours and 24/7)
- Three queues (Sales, Tech Support, Customer Service)
- Corresponding routing profiles for each department
- Test agents for each department
- Basic IVR call flow with options for different departments
- Configuration to stream CTR data to Kinesis for analytics

## Quick Start

1. Deploy the infrastructure using Terraform:
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```

2. After deployment, the Amazon Connect instance will be ready with:
   - Test agents and their login credentials (available in Terraform outputs)
   - Basic IVR flow configured for inbound calls
   - Queues and routing profiles set up for each department

3. You can then access the Amazon Connect instance via the AWS console or directly at:
   ```
   https://<instance_id>.awsapps.com/connect/login
   ```

## Module Configuration Options

### Connect Instance Settings

You can customize the Amazon Connect instance by modifying these variables:

```hcl
module "connect" {
  source = "./connect"
  
  # Instance settings
  instance_alias         = "mycompany"  # Name of the Connect instance
  enable_contact_lens    = true         # Enable Contact Lens for analytics
  enable_contact_flow_logs = true       # Enable logging for contact flows
  
  # Advanced settings - see variables.tf for all options
}
```

### Agent Configuration

Test agents are created automatically. You can disable this or customize the agents:

```hcl
module "connect" {
  # ...other settings...
  
  # Agent settings
  create_test_agents = true  # Set to false to disable agent creation
  agent_password = "YourSecurePassword123!"  # Optional fixed password
  
  # Custom agents list
  test_agents = [
    {
      username   = "custom.agent"
      first_name = "Custom"
      last_name  = "Agent"
      email      = "custom.agent@example.com"
      phone      = "+442071234567"
      groups     = ["Sales"]
    }
  ]
}
```

### Routing and Queue Configuration

You can customize the queues and routing profiles:

```hcl
module "connect" {
  # ...other settings...
  
  # Custom queues
  queues = [
    {
      name = "Premium"
      description = "Queue for premium customers"
      hours_of_operation = "24/7"
    }
  ]
  
  # Custom routing profiles
  routing_profiles = [
    {
      name = "Premium Agent Profile"
      description = "Routing profile for premium agent"
      queues = ["Premium"]
      default_queue = "Premium"
    }
  ]
}
```

### IVR and Contact Flow Configuration

Basic IVR flows are created automatically. You can disable this:

```hcl
module "connect" {
  # ...other settings...
  
  create_basic_ivr = false  # Disable IVR flow creation
}
```

## Testing the Contact Center

### Logging in as an Agent

1. Get the agent credentials from Terraform outputs:
   ```bash
   terraform output -json connect_agent_passwords
   ```

2. Go to your Connect instance URL:
   ```
   https://<instance_id>.awsapps.com/connect/login
   ```

3. Log in with one of the test agent usernames (e.g., `agent.sales1`) and the password

### Making Test Calls

1. After logging in as an agent, set your status to "Available"

2. In a different browser or incognito window, go to:
   ```
   https://<instance_id>.awsapps.com/connect/demo
   ```

3. This opens the test phone interface where you can make test calls to your IVR

4. Follow the prompts to route to different departments

5. The call will be queued to the appropriate department and routed to an available agent

## Generating Test Data

To generate Contact Trace Records (CTR) for your analytics pipeline:

1. Make several test calls using the above procedure

2. Each call interaction will generate a CTR that flows to the Kinesis stream

3. Alternatively, use the provided Python script to generate synthetic data:
   ```bash
   python3 scripts/generate_ctr_data.py
   ```

4. The CTRs will be processed through your analytics pipeline and available in Athena for querying

## Customizing Contact Flows

For more advanced customization of contact flows, you should:

1. Create and design flows in the Amazon Connect web interface

2. Export the flow JSON

3. Include the exported JSON in your Terraform configuration to make it repeatable

## Common Issues and Troubleshooting

### Agent Can't Log In

- Verify the instance is fully deployed (takes about 5 minutes after Terraform completes)
- Check the agent username and password from the Terraform outputs
- Ensure you're using the correct Connect instance URL

### Calls Not Routing

- Verify agents are logged in and set to "Available"
- Check that routing profiles are correctly associated with agents
- Verify queues are correctly associated with routing profiles

### Contact Flows Not Working

- Check the AWS Connect console for errors in the contact flow
- Verify that queue and routing profile references in the flow are correct
- Enable contact flow logs for more detailed debugging

## Next Steps

Once your basic contact center is functioning:

1. Create more sophisticated contact flows in the Connect console
2. Set up skills-based routing for more advanced call distribution
3. Configure recording and analytics through Contact Lens
4. Create custom agent interfaces with the Connect Streams API
5. Build dashboards in Grafana using the CTR data in Athena

For more details on Amazon Connect capabilities, refer to the [AWS documentation](https://docs.aws.amazon.com/connect/)