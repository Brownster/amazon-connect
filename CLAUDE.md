# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands
- `cd terraform && terraform init` - Initialize Terraform working directory
- `cd terraform && terraform validate` - Validate Terraform configuration
- `cd terraform && terraform fmt` - Format Terraform configuration files
- `cd terraform && terraform plan` - Preview changes before applying
- `cd terraform && terraform apply` - Apply the Terraform configuration
- `cd terraform && terraform destroy` - Destroy the infrastructure
- `./scripts/init.sh` - Run initialization script for project setup
- `./scripts/generate_ctr_data.py` - Generate test CTR data for pipeline

## Code Style Guidelines
- **Project Structure**: Follow modular approach with terraform/, scripts/, docs/ directories
- **Terraform**: Use modular structure with separate files for main, variables, outputs
- **Naming**: Use snake_case for resource names and variables
- **Comments**: Maintain section headers and descriptive comments
- **IAM**: Follow least privilege principle for IAM roles and policies
- **Secrets**: Never hardcode credentials; use environment variables or AWS profiles
- **Path References**: Use path.module for file references in Terraform
- **Documentation**: Update README.md when making significant changes