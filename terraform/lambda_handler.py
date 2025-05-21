import os
import json
import boto3
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize S3 client
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Lambda handler function to run the CrewAI AWS Security Audit
    """
    try:
        # Get project name from environment variables
        project_name = os.environ.get('PROJECT_NAME', 'aws-security-auditor')
        
        # No need to retrieve credentials from SSM - using IAM role instead
        logger.info("Starting CrewAI AWS Security Audit using IAM role credentials")
        
        # Import the main module from the CrewAI application
        from aws_infrastructure_security_audit_and_reporting.main import run
        
        # Run the CrewAI application
        result = run()
        
        # Upload the report to S3
        reports_bucket = os.environ.get('REPORTS_BUCKET')
        if os.path.exists('report.md'):
            with open('report.md', 'rb') as file:
                s3.upload_fileobj(
                    file,
                    reports_bucket,
                    f'reports/{context.aws_request_id}/report.md'
                )
            logger.info(f"Report uploaded to s3://{reports_bucket}/reports/{context.aws_request_id}/report.md")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'AWS Security Audit completed successfully',
                'report_location': f's3://{reports_bucket}/reports/{context.aws_request_id}/report.md'
            })
        }
    
    except Exception as e:
        logger.error(f"Error running AWS Security Audit: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error running AWS Security Audit',
                'error': str(e)
            })
        }
