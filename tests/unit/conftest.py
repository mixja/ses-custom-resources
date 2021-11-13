import pytest


@pytest.fixture(autouse=True)
def xray(mocker):
    """
    Disables AWS X-Ray
    """
    mocker.patch('aws_xray_sdk.core.xray_recorder')
    mocker.patch('aws_xray_sdk.core.patch_all')


@pytest.fixture(autouse=True)
def mock_boto3_client(mocker):
    """
    Patches Boto3
    """
    mocker.patch('boto3.client')
    from boto3 import client
    yield client
