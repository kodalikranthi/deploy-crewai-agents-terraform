variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "replica_region" {
  description = "AWS region for S3 cross-region replication"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "aws-security-auditor"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "bedrock_model" {
  description = "AWS Bedrock model to use"
  type        = string
  default     = "bedrock/anthropic.claude-3-sonnet-20240229-v1:0"
}

# Removed AWS credential variables as we're now using IAM roles

variable "serper_api_key" {
  description = "Serper API Key for research (optional)"
  type        = string
  sensitive   = true
  default     = ""
}
