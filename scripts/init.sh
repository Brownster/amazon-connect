#!/bin/bash
# Initialization script for the AWS Connect Analytics Pipeline project
# This script checks dependencies, generates SSH keys, and prepares the environment

# Function to check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${PROJECT_ROOT}/.init_output.log"
}

# Get project root directory (assumes script is in scripts/ subdirectory)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

# Create log file
echo "AWS Connect Analytics Pipeline - Initialization Log" > .init_output.log
echo "Started at: $(date)" >> .init_output.log
echo "-------------------------------------------" >> .init_output.log

log "Starting project initialization..."

# Check required tools
log "Checking dependencies..."

MISSING_DEPS=0

# Check for AWS CLI
if ! check_command aws; then
    log "❌ AWS CLI is not installed. Please install it from https://aws.amazon.com/cli/"
    MISSING_DEPS=1
else
    AWS_VERSION=$(aws --version 2>&1)
    log "✅ AWS CLI is installed: $AWS_VERSION"
fi

# Check for Terraform
if ! check_command terraform; then
    log "❌ Terraform is not installed. Please install it from https://www.terraform.io/downloads"
    MISSING_DEPS=1
else
    TF_VERSION=$(terraform version -json | grep "terraform_version" | cut -d'"' -f4)
    log "✅ Terraform is installed: v$TF_VERSION"
fi

# Check for Python 3
if ! check_command python3; then
    log "❌ Python 3 is not installed. Please install it from https://www.python.org/downloads/"
    MISSING_DEPS=1
else
    PY_VERSION=$(python3 --version 2>&1)
    log "✅ Python is installed: $PY_VERSION"
fi

# Check for pip
if ! check_command pip3; then
    log "❌ pip is not installed. Please install it with your package manager."
    MISSING_DEPS=1
else
    PIP_VERSION=$(pip3 --version 2>&1)
    log "✅ pip is installed: $PIP_VERSION"
fi

if [ $MISSING_DEPS -eq 1 ]; then
    log "❌ Some dependencies are missing. Please install them and run this script again."
    exit 1
fi

# Install Python dependencies
log "Installing Python dependencies..."
pip3 install boto3 -q
if [ $? -eq 0 ]; then
    log "✅ Python dependencies installed successfully"
else
    log "❌ Failed to install Python dependencies"
    exit 1
fi

# Check AWS credentials
log "Checking AWS credentials..."
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ $? -eq 0 ]; then
    log "✅ AWS credentials found. Account: $AWS_ACCOUNT"
else
    log "⚠️ AWS credentials not found or invalid. You'll need to configure them before running Terraform."
    log "Run 'aws configure' to set up your credentials."
fi

# Generate SSH keys if they don't exist
if [ ! -f "${PROJECT_ROOT}/grafana-key" ]; then
    log "Generating SSH keys for Grafana..."
    bash "${PROJECT_ROOT}/scripts/generate_ssh_key.sh"
    if [ $? -eq 0 ]; then
        log "✅ SSH keys generated successfully"
    else
        log "❌ Failed to generate SSH keys"
        exit 1
    fi
else
    log "✅ SSH keys already exist"
fi

# Verify Terraform configuration
log "Verifying Terraform configuration..."
cd "${PROJECT_ROOT}/terraform" || exit 1
terraform init -backend=false -input=false > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log "✅ Terraform configuration is valid"
else
    log "❌ Terraform configuration validation failed"
    exit 1
fi

# Remind about IAM permissions
log "Checking IAM policies..."
log "⚠️ Remember to create and attach the IAM policies before running Terraform"
log "See the iam-policies/ directory for example policies to use"

# Print final instructions
log "✅ Initialization complete!"
log ""
log "Next steps:"
log "1. Configure AWS credentials (if not already done): aws configure"
log "2. Create and attach IAM policies - see iam-policies/ directory"
log "3. Run Terraform:"
log "   cd terraform"
log "   terraform init"
log "   terraform plan"
log "   terraform apply"
log ""
log "For more information, see the README.md file."

echo ""
echo "✅ Initialization complete! See .init_output.log for details."
echo "For next steps, see the README.md file."