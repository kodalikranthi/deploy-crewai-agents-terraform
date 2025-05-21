provider "aws" {
  region = var.aws_region
}

# Provider for replica region (for S3 cross-region replication)
provider "aws" {
  alias  = "replica_region"
  region = var.replica_region
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Random string to ensure unique resource names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# SNS topic for S3 event notifications
resource "aws_sns_topic" "s3_event_notification" {
  name = "${var.project_name}-s3-event-notification"
  
  # Enable server-side encryption for SNS topic
  kms_master_key_id = "alias/aws/sns"  # Using AWS managed KMS key for SNS
  
  # Enable server-side encryption
  server_side_encryption {
    enabled = true
  }
}

# SNS topic for S3 event notifications in replica region
resource "aws_sns_topic" "s3_event_notification_replica" {
  provider = aws.replica_region
  name     = "${var.project_name}-s3-event-notification-replica"
  
  # Enable server-side encryption for SNS topic
  kms_master_key_id = "alias/aws/sns"  # Using AWS managed KMS key for SNS
  
  # Enable server-side encryption
  server_side_encryption {
    enabled = true
  }
}

# KMS key for S3 bucket encryption
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 bucket encryption"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      }
    ]
  })
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-s3-key"
    Environment = var.environment
  }
}

# KMS key for replica region
resource "aws_kms_key" "s3_key_replica" {
  provider              = aws.replica_region
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      }
    ]
  })
  description           = "KMS key for S3 bucket encryption in replica region"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-s3-key-replica"
    Environment = var.environment
  }
}

# S3 bucket for access logs
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.project_name}-access-logs-${random_string.suffix.result}"

  tags = {
    Name        = "${var.project_name}-access-logs"
    Environment = var.environment
  }
}

# S3 bucket notification for access logs bucket
resource "aws_s3_bucket_notification" "access_logs_notification" {
  bucket = aws_s3_bucket.access_logs.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix = ".log"
  }
}

# Enable versioning for access logs bucket
resource "aws_s3_bucket_versioning" "access_logs_versioning" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for access logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_encryption" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block public access for access logs bucket
resource "aws_s3_bucket_public_access_block" "access_logs_public_access_block" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for access logs bucket
resource "aws_s3_bucket_lifecycle_configuration" "access_logs_lifecycle" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# Create access logs bucket in replica region
resource "aws_s3_bucket" "access_logs_replica" {
  provider = aws.replica_region
  bucket   = "${var.project_name}-access-logs-replica-${random_string.suffix.result}"

  tags = {
    Name        = "${var.project_name}-access-logs-replica"
    Environment = var.environment
  }
}

# Enable versioning for access logs replica bucket
resource "aws_s3_bucket_versioning" "access_logs_replica_versioning" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.access_logs_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for access logs replica bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_replica_encryption" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.access_logs_replica.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key_replica.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# S3 bucket notification for access logs replica bucket
resource "aws_s3_bucket_notification" "access_logs_replica_notification" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.access_logs_replica.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification_replica.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix = ".log"
  }
}

# Block public access for access logs replica bucket
resource "aws_s3_bucket_public_access_block" "access_logs_replica_public_access_block" {
  provider                = aws.replica_region
  bucket                  = aws_s3_bucket.access_logs_replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for access logs replica bucket
resource "aws_s3_bucket_lifecycle_configuration" "access_logs_replica_lifecycle" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.access_logs_replica.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# Configure replication for access logs bucket
resource "aws_s3_bucket_replication_configuration" "access_logs_replication" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.access_logs_versioning]

  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "AccessLogsReplication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.access_logs_replica.arn
      storage_class = "STANDARD"
    }
  }
}

# Create an S3 bucket to store the application code
resource "aws_s3_bucket" "app_code" {
  bucket = "${var.project_name}-code-${random_string.suffix.result}"

  tags = {
    Name        = "${var.project_name}-code"
    Environment = var.environment
  }
}

# S3 bucket notification for app code bucket
resource "aws_s3_bucket_notification" "app_code_notification" {
  bucket = aws_s3_bucket.app_code.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

# Enable versioning for app code bucket
resource "aws_s3_bucket_versioning" "app_code_versioning" {
  bucket = aws_s3_bucket.app_code.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for app code bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "app_code_encryption" {
  bucket = aws_s3_bucket.app_code.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Enable access logging for app code bucket
resource "aws_s3_bucket_logging" "app_code_logging" {
  bucket = aws_s3_bucket.app_code.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "app-code-logs/"
}

# Block public access for app code bucket
resource "aws_s3_bucket_public_access_block" "app_code_public_access_block" {
  bucket                  = aws_s3_bucket.app_code.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for app code bucket
resource "aws_s3_bucket_lifecycle_configuration" "app_code_lifecycle" {
  bucket = aws_s3_bucket.app_code.id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Create replica bucket in another region
resource "aws_s3_bucket" "app_code_replica" {
  provider = aws.replica_region
  bucket   = "${var.project_name}-code-replica-${random_string.suffix.result}"

  tags = {
    Name        = "${var.project_name}-code-replica"
    Environment = var.environment
  }
}

# S3 bucket notification for app code replica bucket
resource "aws_s3_bucket_notification" "app_code_replica_notification" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.app_code_replica.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification_replica.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

# Enable versioning for app code replica bucket
resource "aws_s3_bucket_versioning" "app_code_replica_versioning" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.app_code_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for app code replica bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "app_code_replica_encryption" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.app_code_replica.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key_replica.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Enable access logging for app code replica bucket
resource "aws_s3_bucket_logging" "app_code_replica_logging" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.app_code_replica.id

  target_bucket = aws_s3_bucket.access_logs_replica.id
  target_prefix = "app-code-replica-logs/"
}

# Block public access for app code replica bucket
resource "aws_s3_bucket_public_access_block" "app_code_replica_public_access_block" {
  provider                = aws.replica_region
  bucket                  = aws_s3_bucket.app_code_replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for app code replica bucket
resource "aws_s3_bucket_lifecycle_configuration" "app_code_replica_lifecycle" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.app_code_replica.id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# IAM role for S3 replication
resource "aws_iam_role" "replication_role" {
  name = "${var.project_name}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for S3 replication
resource "aws_iam_policy" "replication_policy" {
  name = "${var.project_name}-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.app_code.arn,
          aws_s3_bucket.audit_reports.arn,
          aws_s3_bucket.access_logs.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.app_code.arn}/*",
          "${aws_s3_bucket.audit_reports.arn}/*",
          "${aws_s3_bucket.access_logs.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.app_code_replica.arn}/*",
          "${aws_s3_bucket.audit_reports_replica.arn}/*",
          "${aws_s3_bucket.access_logs_replica.arn}/*"
        ]
      },
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.s3_key.arn
      },
      {
        Action = [
          "kms:Encrypt"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.s3_key_replica.arn
      }
    ]
  })
}

# Attach replication policy to role
resource "aws_iam_role_policy_attachment" "replication_policy_attachment" {
  role       = aws_iam_role.replication_role.name
  policy_arn = aws_iam_policy.replication_policy.arn
}

# Configure replication for app code bucket
resource "aws_s3_bucket_replication_configuration" "app_code_replication" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.app_code_versioning]

  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.app_code.id

  rule {
    id     = "EntireBucketReplication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.app_code_replica.arn
      storage_class = "STANDARD"
    }
  }
}

# S3 bucket notification for audit reports bucket
resource "aws_s3_bucket_notification" "audit_reports_notification" {
  bucket = aws_s3_bucket.audit_reports.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

# S3 bucket for storing audit reports
resource "aws_s3_bucket" "audit_reports" {
  bucket = "${var.project_name}-reports-${random_string.suffix.result}"

  tags = {
    Name        = "${var.project_name}-reports"
    Environment = var.environment
  }
}

# Enable versioning for audit reports bucket
resource "aws_s3_bucket_versioning" "audit_reports_versioning" {
  bucket = aws_s3_bucket.audit_reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for audit reports bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "audit_reports_encryption" {
  bucket = aws_s3_bucket.audit_reports.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Enable access logging for audit reports bucket
resource "aws_s3_bucket_logging" "audit_reports_logging" {
  bucket = aws_s3_bucket.audit_reports.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "audit-reports-logs/"
}

# Block public access for audit reports bucket
resource "aws_s3_bucket_public_access_block" "audit_reports_public_access_block" {
  bucket                  = aws_s3_bucket.audit_reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for audit reports bucket
resource "aws_s3_bucket_lifecycle_configuration" "audit_reports_lifecycle" {
  bucket = aws_s3_bucket.audit_reports.id

  rule {
    id     = "archive-old-reports"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# Create replica bucket for audit reports in another region
resource "aws_s3_bucket" "audit_reports_replica" {
  provider = aws.replica_region
  bucket   = "${var.project_name}-reports-replica-${random_string.suffix.result}"

  tags = {
    Name        = "${var.project_name}-reports-replica"
    Environment = var.environment
  }
}

# Enable versioning for audit reports replica bucket
resource "aws_s3_bucket_versioning" "audit_reports_replica_versioning" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.audit_reports_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for audit reports replica bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "audit_reports_replica_encryption" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.audit_reports_replica.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key_replica.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Enable access logging for audit reports replica bucket
resource "aws_s3_bucket_logging" "audit_reports_replica_logging" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.audit_reports_replica.id

  target_bucket = aws_s3_bucket.access_logs_replica.id
  target_prefix = "audit-reports-replica-logs/"
}

# Block public access for audit reports replica bucket
resource "aws_s3_bucket_public_access_block" "audit_reports_replica_public_access_block" {
  provider                = aws.replica_region
  bucket                  = aws_s3_bucket.audit_reports_replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for audit reports replica bucket
resource "aws_s3_bucket_lifecycle_configuration" "audit_reports_replica_lifecycle" {
  provider = aws.replica_region
  bucket   = aws_s3_bucket.audit_reports_replica.id

  rule {
    id     = "archive-old-reports"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# Configure replication for audit reports bucket
resource "aws_s3_bucket_replication_configuration" "audit_reports_replication" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.audit_reports_versioning]

  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.audit_reports.id

  rule {
    id     = "EntireBucketReplication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.audit_reports_replica.arn
      storage_class = "STANDARD"
    }
  }
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Update the IAM policy for Bedrock access to include additional permissions
resource "aws_iam_policy" "bedrock_policy" {
  name        = "${var.project_name}-bedrock-policy"
  description = "Policy for accessing AWS Bedrock models with least privilege"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model}"
      },
      {
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Effect   = "Allow"
        Resource = "*"
        # NOTE: Wildcard resource is necessary for these Bedrock list/get operations
        # as they don't support resource-level permissions. This follows AWS best practices
        # for these specific API calls. We restrict by region in the condition below.
        Condition = {
          StringEquals = {
            "aws:RequestedRegion": var.aws_region
          }
        }
      }
    ]
  })
}

# IAM policy for S3 access to write reports
resource "aws_iam_policy" "s3_policy" {
  name        = "${var.project_name}-s3-policy"
  description = "Policy for accessing S3 to write reports"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.audit_reports.arn}",
          "${aws_s3_bucket.audit_reports.arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for KMS access
resource "aws_iam_policy" "kms_policy" {
  name        = "${var.project_name}-kms-policy"
  description = "Policy for accessing KMS keys"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.s3_key.arn
      }
    ]
  })
}

# Attach S3 policy to Lambda role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

# Attach KMS policy to Lambda role
resource "aws_iam_role_policy_attachment" "kms_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.kms_policy.arn
}

# Attach Bedrock policy to Lambda role
resource "aws_iam_role_policy_attachment" "bedrock_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.bedrock_policy.arn
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create a zip package of the application code
data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/lambda_package.zip"
}

# Upload the Lambda package to S3
resource "aws_s3_object" "lambda_package" {
  bucket = aws_s3_bucket.app_code.bucket
  key    = "lambda_package.zip"
  source = data.archive_file.lambda_package.output_path
  etag   = filemd5(data.archive_file.lambda_package.output_path)
}

# Create a Lambda function to run the CrewAI application
resource "aws_lambda_function" "crewai_lambda" {
  function_name = "${var.project_name}-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "main.lambda_handler"
  runtime       = "python3.10"  # CrewAI requires Python >=3.10 and <3.13
  timeout       = 900  # 15 minutes, maximum Lambda timeout
  memory_size   = 1024
  reserved_concurrent_executions = 1  # Limit concurrent executions to 1

  s3_bucket = aws_s3_bucket.app_code.bucket
  s3_key    = aws_s3_object.lambda_package.key

  # Fix #2: KMS key for environment variable encryption
  kms_key_arn = aws_kms_key.lambda_env_key.arn
  
  # Fix #3: VPC configuration
  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  
  # Enable X-Ray tracing for better debugging and performance analysis
  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      AWS_REGION_NAME     = var.aws_region
      MODEL               = var.bedrock_model
      REPORT_BUCKET_NAME  = aws_s3_bucket.audit_reports.bucket
      # Secrets will be retrieved from Parameter Store
    }
  }

  depends_on = [
    aws_s3_object.lambda_package
  ]
}

  # Remove SSM parameters for credentials since we're using IAM roles
  # Create SSM parameter for Serper API Key only if provided
  resource "aws_ssm_parameter" "serper_api_key" {
    count       = var.serper_api_key != "" ? 1 : 0
    name        = "/security-auditor/serper_api_key"
    description = "Serper API Key for research"
    type        = "SecureString"
    value       = var.serper_api_key
    key_id      = aws_kms_key.lambda_env_key.arn  # Use customer-managed KMS key
  }

# CloudWatch Log Group for Lambda with 365-day retention and KMS encryption
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.crewai_lambda.function_name}"
  retention_in_days = 365  # Set to 365 days (1 year) for compliance
  kms_key_id        = aws_kms_key.lambda_env_key.arn  # Use existing KMS key for encryption
}

# EventBridge rule to trigger the Lambda function on a schedule (e.g., daily)
resource "aws_cloudwatch_event_rule" "daily_audit" {
  name                = "${var.project_name}-daily-audit"
  description         = "Trigger AWS security audit daily"
  schedule_expression = "cron(0 0 * * ? *)"  # Run at midnight UTC every day
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_audit.name
  target_id = "TriggerLambda"
  arn       = aws_lambda_function.crewai_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.crewai_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_audit.arn
}

# Output the S3 bucket names and Lambda function name
output "code_bucket_name" {
  value = aws_s3_bucket.app_code.bucket
}

output "reports_bucket_name" {
  value = aws_s3_bucket.audit_reports.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.crewai_lambda.function_name
}
# 2. Fix for High Severity Issue #2: Unencrypted Environment Variables
# Implement KMS encryption for Lambda environment variables
resource "aws_kms_key" "lambda_env_key" {
  description             = "KMS key for Lambda environment variables encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Name        = "${var.project_name}-lambda-env-key"
    Environment = var.environment
  }
}

# 3. Fix for High Severity Issue #3: Missing VPC Configuration for Lambda
# Create a VPC for Lambda
resource "aws_vpc" "lambda_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Create private subnets for Lambda
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  
  tags = {
    Name        = "${var.project_name}-private-subnet-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  
  tags = {
    Name        = "${var.project_name}-private-subnet-2"
    Environment = var.environment
  }
}

# Create security group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda function"
  vpc_id      = aws_vpc.lambda_vpc.id
  
  # Replace overly permissive egress rule with specific rules
  # Allow HTTPS outbound for AWS API calls
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS outbound for AWS API calls"
  }
  
  # Allow DNS resolution
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow DNS resolution"
  }
  
  tags = {
    Name        = "${var.project_name}-lambda-sg"
    Environment = var.environment
  }
}

# Create NAT Gateway for Lambda to access internet
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  
  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.lambda_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = false
  
  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.lambda_vpc.id
  
  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.lambda_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  
  tags = {
    Name        = "${var.project_name}-nat-gw"
    Environment = var.environment
  }
  
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.lambda_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  
  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_rta_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_rta_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# Add VPC policy to Lambda role
resource "aws_iam_role_policy_attachment" "vpc_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}
