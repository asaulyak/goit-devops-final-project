variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "bucket_name" {
  description = "S3 bucket for Terraform"
  type        = string
  default     = "goit-devops-final-terraform-state"
}

variable "table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "terraform-locks"
}

variable "vpc_cidr_block" {
  description = "CIDR for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "CIDR for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "CIDR for private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "final-project-vpc"
}

variable "ecr_name" {
  description = "ECR name"
  type        = string
  default     = "final-project-ecr"
}

variable "scan_on_push" {
  description = "Autoscan on push"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "final-project-eks"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

variable "node_group_name" {
  description = "EKS node group name"
  type        = string
  default     = "final-project-node-group"
}

variable "node_group_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Project     = "Final Project"
  }
}

# Jenkins variables
variable "jenkins_namespace" {
  description = "Kubernetes namespace for Jenkins"
  type        = string
  default     = "jenkins"
}

variable "jenkins_chart_version" {
  description = "Jenkins Helm chart version"
  type        = string
  default     = "5.0.0"
}

variable "jenkins_resources" {
  description = "Resource limits and requests for Jenkins controller"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "1000m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

variable "jenkins_agent_resources" {
  description = "Resource limits and requests for Jenkins agents"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

# Argo CD variables
variable "argocd_namespace" {
  description = "Kubernetes namespace for Argo CD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "7.2.0"
}

variable "git_repository_url" {
  description = "Git repository URL for Argo CD to monitor"
  type        = string
  default     = ""
}

variable "git_repository_path" {
  description = "Path to Helm chart in Git repository"
  type        = string
  default     = "charts/django-app"
}

variable "jenkins_git_repository_url" {
  description = "Git repository URL for Jenkins pipeline"
  type        = string
  default     = ""
}

variable "jenkins_git_branch" {
  description = "Git branch for Jenkins pipeline"
  type        = string
  default     = "main"
}

variable "argocd_application_name" {
  description = "Name of the Argo CD application"
  type        = string
  default     = "django-app"
}

variable "argocd_target_namespace" {
  description = "Target namespace for the application"
  type        = string
  default     = "default"
}

variable "argocd_target_revision" {
  description = "Target Git revision (branch or tag)"
  type        = string
  default     = "main"
}

# RDS variables
variable "rds_enabled" {
  description = "Enable RDS database creation"
  type        = bool
  default     = true
}

variable "db_identifier" {
  description = "Unique identifier for the database"
  type        = string
  default     = "final-project-db"
}

variable "db_engine" {
  description = "Database engine (postgres, mysql)"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.4"
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for autoscaling in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "mydb"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = true
}

