output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.crewai_lambda.arn
}

output "lambda_function_url" {
  description = "URL of the Lambda function"
  value       = aws_lambda_function.crewai_lambda.invoke_arn
}

output "code_bucket_url" {
  description = "URL of the S3 bucket containing the code"
  value       = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.app_code.bucket}"
}

output "reports_bucket_url" {
  description = "URL of the S3 bucket containing the reports"
  value       = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.audit_reports.bucket}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
