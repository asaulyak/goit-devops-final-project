# Infrastructure Deployment Guide

This guide will walk you through deploying the Final Project infrastructure to AWS.

## Prerequisites

Before starting, ensure you have:

1. **AWS CLI installed and configured**
   ```bash
   aws --version
   aws configure
   ```

2. **Terraform installed** (version >= 1.0)
   ```bash
   terraform version
   ```

3. **kubectl installed** (for Kubernetes access)
   ```bash
   kubectl version --client
   ```

4. **Helm 3 installed** (optional, for manual Helm operations)
   ```bash
   helm version
   ```

5. **AWS Account** with appropriate permissions for:
   - S3, DynamoDB, VPC, ECR, EKS, RDS, IAM, EC2

## Step 1: Create S3 Backend and DynamoDB Table

The Terraform backend requires an S3 bucket and DynamoDB table to store state and manage locks. You need to create these **before** running `terraform init`.

### Option A: Create manually via AWS Console

1. **Create S3 bucket:**
   - Go to S3 in AWS Console
   - Create bucket: `goit-devops-final-terraform-state`
   - Region: `us-east-2` (or your preferred region)
   - Enable versioning (recommended)
   - Enable encryption (recommended)

2. **Create DynamoDB table:**
   - Go to DynamoDB in AWS Console
   - Create table: `terraform-locks`
   - Partition key: `LockID` (String)
   - Region: `us-east-2` (same as S3 bucket)

### Option B: Create via AWS CLI

```bash
# Create S3 bucket
aws s3 mb s3://goit-devops-final-terraform-state --region us-east-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket goit-devops-final-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket goit-devops-final-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-2
```

### Option C: Create via separate Terraform (recommended for first-time setup)

If the backend resources don't exist, you can bootstrap them:

```bash
# Create a temporary bootstrap directory
mkdir terraform-bootstrap
cd terraform-bootstrap

# Create bootstrap main.tf
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "goit-devops-final-terraform-state"
  
  versioning {
    enabled = true
  }
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"
  }
}
EOF

# Initialize and apply bootstrap
terraform init
terraform plan
terraform apply

# Clean up
cd ..
rm -rf terraform-bootstrap
```

## Step 2: Configure Terraform Variables

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` and set required values:**
   ```bash
   nano terraform.tfvars  # or use your preferred editor
   ```

   **IMPORTANT: You MUST set the following:**
   - `db_password` - A secure password for your RDS database
   - `jenkins_git_repository_url` - Your Git repository URL (optional, but recommended)
   - `git_repository_url` - Your Git repository URL for Argo CD (optional)

   Example:
   ```hcl
   # ... other variables ...
   
   # RDS Database Configuration
   db_password = "YourSecurePassword123!"  # CHANGE THIS!
   
   # Jenkins Git Repository Configuration
   jenkins_git_repository_url = "https://github.com/your-username/your-repo.git"
   jenkins_git_branch = "main"
   
   # Git Repository Configuration (for Argo CD)
   git_repository_url = "https://github.com/your-username/your-repo.git"
   ```

3. **Add `terraform.tfvars` to `.gitignore`** (if not already present):
   ```bash
   echo "terraform.tfvars" >> .gitignore
   echo "*.tfstate" >> .gitignore
   echo "*.tfstate.backup" >> .gitignore
   echo ".terraform/" >> .gitignore
   echo ".terraform.lock.hcl" >> .gitignore
   ```

## Step 3: Initialize Terraform

```bash
# Initialize Terraform (downloads providers and sets up backend)
terraform init
```

If you see errors about the S3 bucket or DynamoDB table not existing, go back to Step 1.

## Step 4: Review the Deployment Plan

```bash
# Review what Terraform will create
terraform plan
```

This will show you:
- Resources that will be created
- Estimated costs (if AWS pricing is available)
- Any potential issues

**Review carefully** - this will create billable AWS resources!

## Step 5: Deploy the Infrastructure

```bash
# Apply the configuration (creates all resources)
terraform apply
```

You will be prompted to confirm. Type `yes` to proceed.

**Note:** This process can take 15-30 minutes, especially for:
- EKS cluster creation (~10-15 minutes)
- RDS database creation (~5-10 minutes)
- Jenkins and Argo CD Helm installations (~5 minutes)

## Step 6: Configure kubectl

After the deployment completes, configure kubectl to access your EKS cluster:

```bash
# Get the command from Terraform output
terraform output kubectl_config_command

# Or run it directly
aws eks update-kubeconfig --region us-east-2 --name final-project-eks

# Verify connection
kubectl get nodes
```

## Step 7: Access Jenkins

1. **Get Jenkins LoadBalancer URL:**
   ```bash
   kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

2. **Get Jenkins admin password:**
   ```bash
   kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
   echo
   ```

3. **Access Jenkins:**
   - Open the LoadBalancer URL in your browser
   - Login with username: `admin` and the password from step 2

## Step 8: Access Argo CD

1. **Get Argo CD LoadBalancer URL:**
   ```bash
   kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

2. **Get Argo CD admin password:**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
   echo
   ```

3. **Access Argo CD:**
   - Open the LoadBalancer URL in your browser
   - Login with username: `admin` and the password from step 2

## Step 9: Get Database Connection Information

```bash
# Get RDS endpoint
terraform output -raw rds_instance_address

# Get RDS port
terraform output -raw rds_instance_port

# Get full connection info
terraform output database_connection_info
```

Use this information to configure your Django application's database connection.

## Step 10: Configure Jenkins Pipeline

1. **Set ECR Repository URL in Jenkins:**
   - Get ECR URL: `terraform output -raw ecr_repository_url`
   - In Jenkins, create a new Pipeline job
   - Use the `Jenkinsfile` from the root directory
   - Set the `ECR_REPOSITORY_URL` environment variable in the pipeline configuration

2. **Configure Git credentials (if needed):**
   - In Jenkins, go to: Manage Jenkins → Credentials → Add Credentials
   - Add your GitHub credentials with ID: `github-credentials`

## Troubleshooting

### Backend initialization fails
- Ensure S3 bucket and DynamoDB table exist (see Step 1)
- Check AWS credentials: `aws sts get-caller-identity`
- Verify region matches in `backend.tf` and your AWS config

### EKS cluster creation fails
- Check IAM permissions for EKS
- Ensure you have sufficient service quotas
- Review CloudFormation stack events in AWS Console

### RDS creation fails
- Verify `db_password` is set in `terraform.tfvars`
- Check RDS service quotas
- Ensure subnets are in at least 2 availability zones

### Jenkins/Argo CD pods not starting
- Check pod status: `kubectl get pods -n jenkins` or `kubectl get pods -n argocd`
- View logs: `kubectl logs <pod-name> -n <namespace>`
- Check LoadBalancer creation: `kubectl get svc -n jenkins` or `kubectl get svc -n argocd`

## Cost Estimation

Approximate monthly costs (us-east-2 region):
- EKS Cluster: ~$72/month
- EKS Node Group (2x t3.medium): ~$60/month
- RDS (db.t3.micro): ~$15/month
- Load Balancers (2x): ~$30/month
- ECR, S3, DynamoDB: ~$5/month
- **Total: ~$180-200/month**

**Important:** Always destroy resources when not in use to avoid charges!

## Destroying the Infrastructure

When you're done testing:

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy
```