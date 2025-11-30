terraform {
  backend "s3" {
    bucket         = "goit-devops-final-terraform-state"
    key            = "final-project/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

