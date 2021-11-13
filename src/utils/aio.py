import os
import asyncio
from functools import wraps, partial
from concurrent.futures import ThreadPoolExecutor

from config import log
from utils import jsonify

# Worker pool
worker_pool = ThreadPoolExecutor(max_workers=int(os.environ.get('MAX_WORKERS', 4)))


def worker(func):
    """
    Runs blocking code asynchronously in worker thread from worker pool
    """
    @wraps(func)
    async def run(*args, **kwargs):
        pfunc = partial(func, *args, **kwargs)
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(worker_pool, pfunc)
    return run


def async_handler(handler):
    """
    Async handler
    """
    @wraps(handler)
    def wrap(event, context):
        log.info(f'Received event {jsonify(event)}')
        loop = asyncio.get_event_loop()
        return loop.run_until_complete(handler(event, context))
    return wrap


def graphql_handler(handler):
    """
    GraphQL async handler
    """
    @wraps(handler)
    def wrap(event, context):
        try:
            log.info(f'Received event {jsonify(event)}')
            loop = asyncio.get_event_loop()
            result = loop.run_until_complete(handler(event, context))
        except Exception as e:
            log.exception('An exception occurred')
            message = getattr(e, 'message') if hasattr(e, 'message') else str(e)
            result = {'error': {'message': message} }
        log.info(f'Result: {jsonify(result)}')
        return result
    return wrap
