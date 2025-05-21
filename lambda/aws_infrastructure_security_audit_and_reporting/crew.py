from crewai import Agent, Crew, Process, Task
from langchain_openai import ChatOpenAI

import os

class AwsInfrastructureSecurityAuditAndReportingCrew():
    """AwsInfrastructureSecurityAuditAndReporting crew"""

    def __init__(self) -> None:
        self.llm = ChatOpenAI(
            model_name="gpt-4-turbo",
            temperature=0.7
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
            agent=self.security_analyst(),
            context=[
                "Focus on common AWS security issues like public S3 buckets, overly permissive IAM policies, and unencrypted data",
                "Check for compliance with AWS Well-Architected Framework security pillar",
                "Identify potential data exposure risks"
            ]
        )

    def generate_report_task(self) -> Task:
        return Task(
            description="Create a comprehensive security audit report with findings, risk assessments, and remediation recommendations",
            expected_output="A professional security audit report in markdown format with executive summary, detailed findings, risk ratings, and prioritized remediation steps",
            agent=self.report_writer(),
            context=[
                "The report should be suitable for both technical and non-technical stakeholders",
                "Include an executive summary at the beginning",
                "Organize findings by severity (Critical, High, Medium, Low)",
                "For each finding, include a clear description, impact, and specific remediation steps"
            ]
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
