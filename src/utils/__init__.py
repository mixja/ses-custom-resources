import json
from base64 import urlsafe_b64decode, urlsafe_b64encode


def jsonify(data):
    """
    Type safe JSON dump
    """
    return json.dumps(data, default=str)


def encode(data):
    """
    Encodes URL safe base64 value
    """
    encoded = urlsafe_b64encode(data.encode()).decode()
    return encoded.rstrip('=')


def decode(data):
    """
    Decodes URL safe base64 encoded value
    """
    padding = 4 - (len(data) % 4)
    data += ('=' * padding)
    return urlsafe_b64decode(data).decode()


def last(data, index=1):
    return data.split('#')[-index]