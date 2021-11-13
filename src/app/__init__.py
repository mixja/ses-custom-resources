from config import log
from utils import jsonify
from utils.aio import async_handler

# Sample Handler
@async_handler
async def handler(event, context):
  # Do something
  return {'statusCode': 200, 'body': jsonify(event)}
