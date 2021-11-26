import pytest


def test_invalid_input(app):
    # Arrange
    event = {}
    # Act
    with pytest.raises(KeyError):
        app.verification_handler(event, {})
