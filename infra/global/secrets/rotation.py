import json
import boto3
import logging
import os
import random
import string

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Lambda function to rotate secrets in AWS Secrets Manager
    """
    logger.info(f"Starting secret rotation for event: {json.dumps(event)}")
    
    secret_arn = os.environ['SECRET_ARN']
    secrets_client = boto3.client('secretsmanager')
    
    try:
        # Get current secret value
        response = secrets_client.get_secret_value(SecretId=secret_arn)
        current_secret = json.loads(response['SecretString'])
        
        # Generate new values
        new_password = generate_password(32)
        new_token = generate_token(64)
        new_api_key = generate_api_key(48)
        
        # Create new secret version
        new_secret = {
            'username': current_secret.get('username', 'podinfo-user'),
            'password': new_password,
            'token': new_token,
            'api_key': new_api_key
        }
        
        # Update secret
        secrets_client.put_secret_value(
            SecretId=secret_arn,
            SecretString=json.dumps(new_secret),
            VersionStages=['AWSPENDING']
        )
        
        # Test the new secret (simulate validation)
        if validate_secret(new_secret):
            # Move to current version
            secrets_client.update_secret_version_stage(
                SecretId=secret_arn,
                VersionStage='AWSCURRENT',
                MoveToVersionId=response['VersionId'],
                RemoveFromVersionId=response['VersionId']
            )
            
            logger.info("Secret rotation completed successfully")
            return {
                'statusCode': 200,
                'body': json.dumps('Secret rotation completed successfully')
            }
        else:
            logger.error("Secret validation failed")
            return {
                'statusCode': 500,
                'body': json.dumps('Secret validation failed')
            }
            
    except Exception as e:
        logger.error(f"Error during secret rotation: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error during secret rotation: {str(e)}')
        }

def generate_password(length):
    """Generate a secure password"""
    characters = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(random.choice(characters) for _ in range(length))

def generate_token(length):
    """Generate a secure token"""
    characters = string.ascii_letters + string.digits
    return ''.join(random.choice(characters) for _ in range(length))

def generate_api_key(length):
    """Generate a secure API key"""
    characters = string.ascii_letters + string.digits
    return ''.join(random.choice(characters) for _ in range(length))

def validate_secret(secret):
    """
    Validate the new secret (simulate validation logic)
    In a real scenario, this would test the secret against the application
    """
    try:
        # Basic validation
        if not secret.get('password') or len(secret['password']) < 8:
            return False
        if not secret.get('token') or len(secret['token']) < 16:
            return False
        if not secret.get('api_key') or len(secret['api_key']) < 16:
            return False
        
        logger.info("Secret validation passed")
        return True
        
    except Exception as e:
        logger.error(f"Secret validation failed: {str(e)}")
        return False
