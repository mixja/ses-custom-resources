def test_invalid_input(app):
    # Arrange
    event = {}
    # Act
    result = app.ruleset_handler_create(event,{})
    # Assert
    assert result['Status'] == 'FAILED'
