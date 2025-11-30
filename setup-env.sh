#!/bin/bash

# Final Project - Environment Setup Script
# This script prepares the environment for Terraform deployment

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUCKET_NAME="goit-devops-final-terraform-state"
DYNAMODB_TABLE="terraform-locks"
AWS_REGION="us-east-2"
TERRAFORM_TFVARS="terraform.tfvars"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Final Project - Environment Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed: $(command -v $1)"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is not installed"
        return 1
    fi
}

# Function to check version
check_version() {
    local cmd=$1
    local version_cmd=$2
    if check_command "$cmd"; then
        local version=$($version_cmd 2>&1 | head -n 1)
        echo -e "  ${BLUE}Version:${NC} $version"
    fi
}

# Step 1: Check Prerequisites
echo -e "${YELLOW}Step 1: Checking Prerequisites...${NC}"
echo ""

MISSING_DEPS=0

# Check AWS CLI
if ! check_command "aws"; then
    echo -e "  ${RED}Please install AWS CLI: https://aws.amazon.com/cli/${NC}"
    MISSING_DEPS=1
else
    check_version "aws" "aws --version"
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "  ${RED}⚠ AWS credentials not configured. Run: aws configure${NC}"
        MISSING_DEPS=1
    else
        AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
        echo -e "  ${GREEN}✓${NC} AWS credentials configured"
        echo -e "  ${BLUE}Account:${NC} $AWS_ACCOUNT"
        echo -e "  ${BLUE}User:${NC} $AWS_USER"
    fi
fi

# Check Terraform
if ! check_command "terraform"; then
    echo -e "  ${RED}Please install Terraform: https://www.terraform.io/downloads${NC}"
    MISSING_DEPS=1
else
    check_version "terraform" "terraform version"
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -n 1 | cut -d' ' -f2)
    echo -e "  ${BLUE}Version:${NC} $TERRAFORM_VERSION"
fi

# Check kubectl
if ! check_command "kubectl"; then
    echo -e "  ${YELLOW}⚠ kubectl is not installed (optional, but recommended)${NC}"
    echo -e "  ${BLUE}Install:${NC} https://kubernetes.io/docs/tasks/tools/${NC}"
else
    check_version "kubectl" "kubectl version --client"
fi

# Check Helm
if ! check_command "helm"; then
    echo -e "  ${YELLOW}⚠ Helm is not installed (optional)${NC}"
    echo -e "  ${BLUE}Install:${NC} https://helm.sh/docs/intro/install/${NC}"
else
    check_version "helm" "helm version"
fi

echo ""

if [ $MISSING_DEPS -eq 1 ]; then
    echo -e "${RED}Please install missing dependencies before continuing.${NC}"
    exit 1
fi

# Step 2: Create S3 Bucket for Terraform Backend
echo -e "${YELLOW}Step 2: Setting up S3 Backend...${NC}"
echo ""

# Check if bucket exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} S3 bucket '$BUCKET_NAME' already exists"
else
    echo -e "${BLUE}Creating S3 bucket:${NC} $BUCKET_NAME"
    
    # Create bucket
    if aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION" 2>&1; then
        echo -e "${GREEN}✓${NC} S3 bucket created successfully"
        
        # Enable versioning
        echo -e "${BLUE}Enabling versioning...${NC}"
        aws s3api put-bucket-versioning \
            --bucket "$BUCKET_NAME" \
            --versioning-configuration Status=Enabled \
            --region "$AWS_REGION"
        echo -e "${GREEN}✓${NC} Versioning enabled"
        
        # Enable encryption
        echo -e "${BLUE}Enabling encryption...${NC}"
        aws s3api put-bucket-encryption \
            --bucket "$BUCKET_NAME" \
            --server-side-encryption-configuration '{
                "Rules": [{
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }]
            }' \
            --region "$AWS_REGION"
        echo -e "${GREEN}✓${NC} Encryption enabled"
        
        # Block public access
        echo -e "${BLUE}Blocking public access...${NC}"
        aws s3api put-public-access-block \
            --bucket "$BUCKET_NAME" \
            --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
            --region "$AWS_REGION"
        echo -e "${GREEN}✓${NC} Public access blocked"
    else
        echo -e "${RED}✗${NC} Failed to create S3 bucket"
        exit 1
    fi
fi

echo ""

# Step 3: Create DynamoDB Table for State Locking
echo -e "${YELLOW}Step 3: Setting up DynamoDB Table...${NC}"
echo ""

# Check if table exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" &>/dev/null; then
    echo -e "${GREEN}✓${NC} DynamoDB table '$DYNAMODB_TABLE' already exists"
else
    echo -e "${BLUE}Creating DynamoDB table:${NC} $DYNAMODB_TABLE"
    
    if aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION" \
        --output text &>/dev/null; then
        echo -e "${GREEN}✓${NC} DynamoDB table created successfully"
        echo -e "${BLUE}Waiting for table to be active...${NC}"
        aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
        echo -e "${GREEN}✓${NC} Table is active"
    else
        echo -e "${RED}✗${NC} Failed to create DynamoDB table"
        exit 1
    fi
fi

echo ""

# Step 4: Setup terraform.tfvars
echo -e "${YELLOW}Step 4: Setting up Terraform Variables...${NC}"
echo ""

if [ -f "$TERRAFORM_TFVARS" ]; then
    echo -e "${YELLOW}⚠${NC} $TERRAFORM_TFVARS already exists"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Skipping terraform.tfvars creation${NC}"
    else
        cp terraform.tfvars.example "$TERRAFORM_TFVARS"
        echo -e "${GREEN}✓${NC} Created $TERRAFORM_TFVARS from example"
        echo -e "${YELLOW}⚠${NC} ${RED}IMPORTANT:${NC} Edit $TERRAFORM_TFVARS and set db_password!"
    fi
else
    cp terraform.tfvars.example "$TERRAFORM_TFVARS"
    echo -e "${GREEN}✓${NC} Created $TERRAFORM_TFVARS from example"
    echo -e "${YELLOW}⚠${NC} ${RED}IMPORTANT:${NC} Edit $TERRAFORM_TFVARS and set db_password!"
fi

echo ""

# Step 5: Initialize Terraform
echo -e "${YELLOW}Step 5: Initializing Terraform...${NC}"
echo ""

if [ -d ".terraform" ]; then
    echo -e "${YELLOW}⚠${NC} Terraform already initialized"
    read -p "Do you want to reinitialize? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Skipping Terraform initialization${NC}"
    else
        terraform init
        echo -e "${GREEN}✓${NC} Terraform initialized"
    fi
else
    terraform init
    echo -e "${GREEN}✓${NC} Terraform initialized"
fi

echo ""

# Step 6: Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Environment Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. ${BLUE}Edit terraform.tfvars:${NC}"
echo "   - Set db_password (REQUIRED)"
echo "   - Set jenkins_git_repository_url (optional)"
echo "   - Set git_repository_url (optional)"
echo ""
echo "2. ${BLUE}Review the deployment plan:${NC}"
echo "   terraform plan"
echo ""
echo "3. ${BLUE}Deploy the infrastructure:${NC}"
echo "   terraform apply"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "- The S3 bucket '$BUCKET_NAME' is ready for Terraform state"
echo "- The DynamoDB table '$DYNAMODB_TABLE' is ready for state locking"
echo "- Make sure to set db_password in terraform.tfvars before running terraform apply"
echo "- Add terraform.tfvars to .gitignore if not already present"
echo ""
echo -e "${GREEN}Setup completed successfully!${NC}"

