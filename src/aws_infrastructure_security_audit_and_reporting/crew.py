from crewai import Agent, Crew, Process, Task
import os
import boto3
from langchain_openai import ChatOpenAI
from langchain_community.chat_models import BedrockChat
from dotenv import load_dotenv

# Load environment variables (for local development only)
load_dotenv()

class AwsInfrastructureSecurityAuditAndReportingCrew():
    """AwsInfrastructureSecurityAuditAndReporting crew"""

    def __init__(self) -> None:
        # Get the model name from environment variables or use a default
        model_name = os.environ.get('MODEL', 'bedrock/anthropic.claude-3-sonnet-20240229-v1:0')
        
        # Check if we're running in AWS Lambda (using IAM role)
        if 'AWS_LAMBDA_FUNCTION_NAME' in os.environ:
            # When running in Lambda, use the IAM role credentials
            # Initialize Bedrock client using boto3's default credential provider chain
            self.llm = BedrockChat(
                model_id=model_name.replace('bedrock/', ''),
                region_name=os.environ.get('AWS_REGION_NAME', 'us-east-1'),
                temperature=0.7
            )
        else:
            # For local development, fall back to environment variables if available
            # Otherwise use a mock LLM for testing
            if 'AWS_ACCESS_KEY_ID' in os.environ and 'AWS_SECRET_ACCESS_KEY' in os.environ:
                self.llm = BedrockChat(
                    model_id=model_name.replace('bedrock/', ''),
                    region_name=os.environ.get('AWS_REGION_NAME', 'us-east-1'),
                    temperature=0.7
                )
            else:
                # Use a mock LLM for testing purposes
                self.llm = ChatOpenAI(
                    model_name="gpt-3.5-turbo",
                    temperature=0.7,
                    api_key="mock-api-key"  # Using a mock API key for demonstration
                )

    def infrastructure_mapper(self) -> Agent:
        return Agent(
            role="AWS Infrastructure Mapper",
            goal="Map and document all AWS infrastructure components",
            backstory="You are an expert AWS infrastructure engineer with deep knowledge of AWS services and architecture patterns.",
            verbose=True,
            llm=self.llm
        )

    def security_analyst(self) -> Agent:
        return Agent(
            role="AWS Security Analyst",
            goal="Identify security vulnerabilities and compliance issues in AWS infrastructure",
            backstory="You are a cybersecurity expert specializing in AWS security best practices and compliance frameworks.",
            verbose=True,
            llm=self.llm
        )

    def report_writer(self) -> Agent:
        return Agent(
            role="Security Report Writer",
            goal="Create comprehensive security audit reports with clear recommendations",
            backstory="You are a technical writer specializing in security documentation with a talent for making complex security concepts understandable.",
            verbose=True,
            llm=self.llm
        )

    def map_aws_infrastructure_task(self) -> Task:
        return Task(
            description="Map the AWS infrastructure by identifying all services, resources, and their configurations",
            expected_output="A comprehensive inventory of AWS resources including EC2 instances, S3 buckets, IAM roles, VPCs, and other services with their configurations",
            agent=self.infrastructure_mapper()
        )

    def exploratory_security_analysis_task(self) -> Task:
        return Task(
            description="Analyze the AWS infrastructure for security vulnerabilities, misconfigurations, and compliance issues",
            expected_output="A detailed security analysis highlighting vulnerabilities, misconfigurations, and compliance gaps with severity ratings",
            agent=self.security_analyst()
        )

    def generate_report_task(self) -> Task:
        return Task(
            description="Create a comprehensive security audit report with findings, risk assessments, and remediation recommendations",
            expected_output="A professional security audit report in markdown format with executive summary, detailed findings, risk ratings, and prioritized remediation steps",
            agent=self.report_writer()
        )


    def crew(self) -> Crew:
        """Creates the AWS Infrastructure Security Audit and Reporting crew"""
        return Crew(
            agents=[
                self.infrastructure_mapper(),
                self.security_analyst(),
                self.report_writer()
            ],
            tasks=[
                self.map_aws_infrastructure_task(),
                self.exploratory_security_analysis_task(),
                self.generate_report_task()
            ],
            process=Process.sequential,
            verbose=True,
        )
