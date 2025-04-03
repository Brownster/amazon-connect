# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands
- `terraform init` - Initialize Terraform working directory
- `terraform validate` - Validate Terraform configuration
- `terraform fmt` - Format Terraform configuration files
- `terraform plan` - Preview changes before applying
- `terraform apply` - Apply the Terraform configuration
- `terraform destroy` - Destroy the infrastructure

## Code Style Guidelines
- **Formatting**: Run `terraform fmt` before committing changes
- **Naming**: Use snake_case for resource names and variables
- **Structure**: Group related resources together in the configuration
- **Comments**: Add meaningful comments for complex configurations
- **Variables**: Use descriptive names and include type constraints
- **Error Handling**: Always validate configurations before applying
- **Modules**: Organize code into reusable modules when applicable
- **State Management**: Be cautious when modifying state files manually