#!/usr/bin/env python
import sys
import os
import logging

# Add the src directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from aws_infrastructure_security_audit_and_reporting.crew import AwsInfrastructureSecurityAuditAndReportingCrew

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# This main file is intended to be a way for your to run your
# crew locally, so refrain from adding unnecessary logic into this file.
# Replace with inputs you want to test with, it will automatically
# interpolate any tasks and agents information

def run():
    """
    Run the crew.
    """
    try:
        crew_instance = AwsInfrastructureSecurityAuditAndReportingCrew()
        result = crew_instance.crew().kickoff()
        
        # Save the result to a file
        with open("report.md", "w") as f:
            f.write(result)
        
        logger.info("Report generated and saved to report.md")
    except Exception as e:
        logger.error(f"Error running the crew: {e}")
        # Create a mock report for demonstration purposes
        with open("report.md", "w") as f:
            f.write("# AWS Security Audit Report (Mock)\n\n")
            f.write("This is a mock report generated because the actual crew execution failed.\n\n")
            f.write("## Error Details\n\n")
            f.write(f"```\n{str(e)}\n```\n\n")
            f.write("## Next Steps\n\n")
            f.write("1. Ensure AWS credentials are properly configured\n")
            f.write("2. Ensure all dependencies are properly installed\n")
            f.write("3. Run the crew again with proper configuration\n")
        logger.info("Mock report generated and saved to report.md")

def train():
    """
    Train the crew for a given number of iterations.
    """
    inputs = {
        
    }
    try:
        AwsInfrastructureSecurityAuditAndReportingCrew().crew().train(n_iterations=int(sys.argv[1]), filename=sys.argv[2], inputs=inputs)

    except Exception as e:
        raise Exception(f"An error occurred while training the crew: {e}")

def replay():
    """
    Replay the crew execution from a specific task.
    """
    try:
        AwsInfrastructureSecurityAuditAndReportingCrew().crew().replay(task_id=sys.argv[1])

    except Exception as e:
        raise Exception(f"An error occurred while replaying the crew: {e}")

def test():
    """
    Test the crew execution and returns the results.
    """
    inputs = {
        
    }
    try:
        AwsInfrastructureSecurityAuditAndReportingCrew().crew().test(n_iterations=int(sys.argv[1]), openai_model_name=sys.argv[2], inputs=inputs)

    except Exception as e:
        raise Exception(f"An error occurred while testing the crew: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: main.py <command> [<args>]")
        sys.exit(1)

    command = sys.argv[1]
    if command == "run":
        run()
    elif command == "train":
        train()
    elif command == "replay":
        replay()
    elif command == "test":
        test()
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
