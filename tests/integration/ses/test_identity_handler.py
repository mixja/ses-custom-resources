def test_invalid_input(run_lambda, stack_outputs):
  event = {}
  response = run_lambda(stack_outputs['SesIdentityProvisioner'], event)
  assert response['errorType'] == 'KeyError'
