import logging
import os

from aws_secretsmanager import SecretsManager
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

# X-Ray
xray_recorder.configure(context_missing='LOG_ERROR')
patch_all()

# Secrets 
SecretsManager()

# Configure logging
logging.basicConfig()
log = logging.getLogger()
log.setLevel(os.environ.get('LOG_LEVEL','INFO'))
