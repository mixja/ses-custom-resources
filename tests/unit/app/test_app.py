import json
from importlib import reload

import pytest


@pytest.fixture
def app(mocker):
    """
    Fixture for node app
    """
    # Patch environment variables
    mocker.patch.dict('os.environ', values=dict(
        MAX_WORKERS='4'
    ))
    import app
    # Override app parameters with mocks here
    # app.client = mock_dynamo_client
    # app.client.get.return_value = mock_event_data
    yield app
    reload(app)


def test_returns_ok(app):
    # Arrange
    event = {'foo': 'bar'}
    # Act
    response = app.handler(event,{})
    # Assert
    assert response['statusCode'] == 200
    assert response['body'] == json.dumps(event)
