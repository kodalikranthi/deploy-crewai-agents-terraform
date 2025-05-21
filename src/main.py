#!/usr/bin/env python
import os
import json
import boto3
import logging
from aws_infrastructure_security_audit_and_reporting.crew import AwsInfrastructureSecurityAuditAndReportingCrew

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    AWS Lambda handler function to run the security audit crew.
    
    Args:
        event (dict): Lambda event data
        context (LambdaContext): Lambda context object
    
    Returns:
        dict: Response containing execution status and report location
    """
    try:
        logger.info("Starting AWS Infrastructure Security Audit")
        
        # Initialize the crew - will use IAM role credentials automatically
        crew_instance = AwsInfrastructureSecurityAuditAndReportingCrew()
        
        # Run the crew with empty inputs (or extract from event if needed)
        inputs = event.get('inputs', {})
        result = crew_instance.crew().kickoff(inputs=inputs)
        
        # Get the S3 bucket name from environment variables or use a default
        s3_bucket = os.environ.get('REPORT_BUCKET_NAME', 'security-audit-reports')
        
        # Generate a timestamp-based filename
        import datetime
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
        report_filename = f"security-audit-report-{timestamp}.md"
        
        # Upload the report to S3 using IAM role
        s3_client = boto3.client('s3')
        s3_client.put_object(
            Bucket=s3_bucket,
            Key=report_filename,
            Body=result,
            ContentType='text/markdown'
        )
        
        logger.info(f"Report generated and uploaded to s3://{s3_bucket}/{report_filename}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Security audit completed successfully',
                'report_location': f"s3://{s3_bucket}/{report_filename}"
            })
        }
        
    except Exception as e:
        logger.error(f"Error running security audit: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error running security audit: {str(e)}'
            })
        }
