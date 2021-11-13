import os
import json

import boto3
import pytest


@pytest.fixture(scope='session')
def stack_outputs():
    """Stack outputs for integration/acceptance testing"""
    cfn = boto3.client('cloudformation')
    stack_name = os.environ.get('STACK_NAME')
    outputs = stack_name and next(iter(cfn.describe_stacks(
        StackName=stack_name,
    )['Stacks']), {}).get('Outputs') or []
    yield { output['OutputKey']: output['OutputValue'] for output in outputs }


@pytest.fixture(scope='session')
def run_lambda():
    import boto3
    client = boto3.client('lambda')

    def run(function_arn, event):
        """
        :param name: lambda function ARN
        :param event: lambda function input
        :returns: lambda function return value
        """
        response = client.invoke(
            FunctionName=function_arn,
            InvocationType='RequestResponse',
            Payload=bytes(json.dumps(event).encode())
        )
        return json.loads(response['Payload'].read())

    return run
