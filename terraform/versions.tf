# ===================================================================
# Terraform and Provider Versions
# ===================================================================
# This file defines version constraints for Terraform and AWS provider
# to ensure compatibility and avoid breaking changes.
# ===================================================================

terraform {
  # Specify the minimum Terraform version required
  required_version = ">= 1.2.0"
  
  # Define specific provider versions for consistency
  required_providers {
    aws = {
      source  = "hashicorp/aws"    # Official HashiCorp AWS provider
      version = "~> 5.0"           # Compatible with version 5.x
    }
  }
}