# Terraform Backend Configuration
# S3 + DynamoDB for state management and locking

terraform {
  backend "s3" {
    bucket         = "podinfo-terraform-state"
    key            = "podinfo/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "podinfo-terraform-locks"
    
    # KMS encryption for state file
    kms_key_id = "alias/podinfo-terraform-state"
  }
}

