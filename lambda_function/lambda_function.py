import boto3
import os
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')
sns = boto3.client('sns')

def lambda_handler(event, context):
    # Retrieve instance ID and SNS Topic ARN from environment variables
    instance_id = os.environ['INSTANCE_ID']
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    
    try:
        # 1. Restart the EC2 instance
        logger.info(f"Initiating restart for instance: {instance_id}")
        ec2.reboot_instances(InstanceIds=[instance_id])
        
        message = f"Successfully initiated reboot for EC2 instance {instance_id} based on Sumo Logic alert."
        logger.info(message)
        
        # 2. Send SNS Notification
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject="EC2 Auto-Restart Notification",
            Message=message
        )
        
        return {
            'statusCode': 200,
            'body': message
        }
        
    except Exception as e:
        error_message = f"Error processing restart for {instance_id}: {str(e)}"
        logger.error(error_message)
        
        sns.publish(
            TopicArn=sns_topic_arn,
            Subject="ERROR: EC2 Auto-Restart Failed",
            Message=error_message
        )
        
        return {
            'statusCode': 500,
            'body': error_message
        }
