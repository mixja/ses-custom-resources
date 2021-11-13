def test_invalid_input(app):
    # Arrange
    event = {}
    # Act
    result = app.identity_handler_create(event,{})
    # Assert
    assert result['Status'] == 'FAILED'
