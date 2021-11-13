import os
import logging
import json
import re

import backoff
import boto3
import requests
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all
from cfn_lambda_handler import Handler

# X-Ray
xray_recorder.configure(context_missing='LOG_ERROR')
patch_all()

# Configure logging
logging.basicConfig()
log = logging.getLogger()
log.setLevel(os.environ.get('LOG_LEVEL', 'INFO'))
jsonify = lambda data: json.dumps(data, default=str)

# Handler
identity_handler = Handler()
ruleset_handler = Handler()

# SES client
ses = boto3.client('ses')
sesv2 = boto3.client('sesv2')


def list_email_identities():
    """List email identities and return map keyed by identity name"""
    identities = sesv2.list_email_identities()['EmailIdentities']
    identities_map = { i['IdentityName']: i for i in identities }
    log.info(f"Current email identities: {jsonify(identities_map)}")
    return identities_map


@backoff.on_predicate(backoff.constant,
                      interval=5,
                      jitter=None,
                      max_time=60,
                      predicate=lambda x: not x)
def check_verification_status(identity):
    """Check verification status every 5 seconds for up to 60 seconds"""
    response = ses.get_identity_verification_attributes(Identities=[identity])
    status = response['VerificationAttributes'][identity]['VerificationStatus']
    log.info(f"{identity} verification status: {status}")
    return status.lower() == 'success'


@backoff.on_predicate(backoff.constant,
                      interval=5,
                      jitter=None,
                      max_time=850,
                      predicate=lambda x: not x)
def verify_email_identity(identity):
    """Send verification email every 60 seconds until successfully verified"""
    log.info(f"Sending verification email to {identity}")
    ses.verify_email_identity(EmailAddress=identity)
    return check_verification_status(identity)


@identity_handler.create
@identity_handler.update
def identity_handler_create(event, context):
    try:
        log.info(f"Received event {jsonify(event)}")
        event['PhysicalResourceId'] = identity = event['ResourceProperties']['Identity']
        policy_name = event['ResourceProperties'].get('PolicyName')
        policy_document = event['ResourceProperties'].get('PolicyDocument')
        identities_map = list_email_identities()
        # Ensure identity exists or is created
        if identity in identities_map:
            ses_identity = sesv2.get_email_identity(EmailIdentity=identity)
        else:
            ses_identity = sesv2.create_email_identity(EmailIdentity=identity)
        log.info(f"SES identity: {jsonify(ses_identity)}")
        # Get DKIM and verification attributes for domain identities
        if ses_identity['IdentityType'] == 'DOMAIN':
            dkim_attributes = ses_identity['DkimAttributes']
            verification_attributes = ses.get_identity_verification_attributes(
                Identities=[identity]
            )['VerificationAttributes']
            log.info(f"Verification attributes: {jsonify(verification_attributes)}")
            event['Data'] = {
                'DkimTokens': dkim_attributes['Tokens'],
                'VerificationToken': verification_attributes[identity]['VerificationToken']
            }
        # Trigger verification email for email identities
        if ses_identity['IdentityType'] == 'EMAIL_ADDRESS':
            verify_email_identity(identity)
        # Configure email identity policies if present
        if ses_identity['IdentityType'] == 'EMAIL_ADDRESS' and policy_name and policy_document:
            policies = sesv2.get_email_identity_policies(EmailIdentity=identity)['Policies']
            if policy_name in policies:
                sesv2.update_email_identity_policy(
                    EmailIdentity=identity,
                    PolicyName=policy_name,
                    Policy=json.dumps(policy_document)
                )
            else:
                sesv2.create_email_identity_policy(
                    EmailIdentity=identity,
                    PolicyName=policy_name,
                    Policy=json.dumps(policy_document)
                )
    except Exception as e:
        log.exception('An exception occurred')
        event['Status'] = 'FAILED'
        event['Reason'] = getattr(e, 'message') if hasattr(e, 'message') else str(e)
    finally:
        return event


@identity_handler.delete
def identity_handler_delete(event, context):
    try:
        log.info(f"Received event {jsonify(event)}")
        identity = event['ResourceProperties']['Identity']
        identities_map = list_email_identities()
        if identity in identities_map:
            sesv2.delete_email_identity(EmailIdentity=identity)
    except Exception as e:
        log.exception('An exception occurred')
        event['Status'] = 'FAILED'
        event['Reason'] = getattr(e, 'message') if hasattr(e, 'message') else str(e)
    finally:
        return event
    

@ruleset_handler.create
@ruleset_handler.update
def ruleset_handler_create(event, context):
    try:
        log.info(f"Received event {jsonify(event)}")
        ruleset = event['ResourceProperties']['RuleSetName']
        ses.set_active_receipt_ruleset(RuleSetName=ruleset)
    except Exception as e:
        log.exception('An exception occurred')
        event['Status'] = 'FAILED'
        event['Reason'] = getattr(e, 'message') if hasattr(e, 'message') else str(e)
    finally:
        return event


@ruleset_handler.delete
def ruleset_handler_delete(event, context):
    try:
        log.info(f"Received event {jsonify(event)}")
        ruleset = event['ResourceProperties']['RuleSetName']
        ses.set_active_receipt_ruleset()
    except Exception as e:
        log.exception('An exception occurred')
        event['Status'] = 'FAILED'
        event['Reason'] = getattr(e, 'message') if hasattr(e, 'message') else str(e)
    finally:
        return event


def verification_handler(event, handler):
    """
    Parses verification message for SES email identity and hits verification URL
    Verification message is sent to SNS topic
    """
    log.info(f"Received event {jsonify(event)}")
    for record in event['Records']:
        message = json.loads(record['Sns']['Message'])
        log.info(f"Received message: {jsonify(message)}")
        # Locate verification URL
        match = re.search(r'https://email-verification.*amazonaws.*', message['content'])
        if match:
            url = match[0].strip()
            log.info(f"Verification URL: {url}")
            response = requests.get(url)
            response.raise_for_status()
