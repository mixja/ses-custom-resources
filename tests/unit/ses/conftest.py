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
    from app import ses as app
    # Override app parameters with mocks here
    # app.client = mock_dynamo_client
    # app.client.get.return_value = mock_event_data
    yield app
    reload(app)