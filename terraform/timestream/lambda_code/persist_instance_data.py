import json
import os
import boto3
import time
from datetime import datetime

# Initialize AWS clients
timestream_write = boto3.client('timestream-write', 
                               region_name=os.environ.get('TIMESTREAM_REGION', 'eu-west-2'))
connect = boto3.client('connect')

database_name = os.environ.get('TIMESTREAM_DATABASE_NAME', 'connect-analytics')

def lambda_handler(event, context):
    """
    Collect Amazon Connect instance data and write to Timestream
    
    This Lambda periodically collects data about Connect instances,
    queues, and agents and persists them to Timestream tables.
    """
    
    print(f"Starting Connect instance data collection")
    
    # Get current timestamp for the records
    current_time = str(int(time.time() * 1000))
    
    try:
        # List Connect instances
        instances = list_connect_instances()
        
        # Process each instance
        for instance in instances:
            instance_id = instance['Id']
            
            # Records for each table
            instance_records = []
            queue_records = []
            user_records = []
            
            # Get instance information
            process_instance(instance, instance_records, current_time)
            
            # Get queues for the instance
            queues = list_queues(instance_id)
            for queue in queues:
                process_queue(instance_id, queue, queue_records, current_time)
            
            # Get users (agents) for the instance
            users = list_users(instance_id)
            for user in users:
                process_user(instance_id, user, user_records, current_time)
            
            # Write records to Timestream
            if instance_records:
                write_records_to_timestream("Instance", instance_records)
            
            if queue_records:
                write_records_to_timestream("Queue", queue_records)
            
            if user_records:
                write_records_to_timestream("User", user_records)
        
    except Exception as e:
        print(f"Error collecting instance data: {str(e)}")
        raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps('Successfully collected Connect instance data')
    }

def list_connect_instances():
    """List all Amazon Connect instances in the account"""
    
    instances = []
    next_token = None
    
    while True:
        if next_token:
            response = connect.list_instances(NextToken=next_token, MaxResults=10)
        else:
            response = connect.list_instances(MaxResults=10)
        
        instances.extend(response.get('InstanceSummaryList', []))
        
        next_token = response.get('NextToken')
        if not next_token:
            break
    
    return instances

def list_queues(instance_id):
    """List all queues for a Connect instance"""
    
    queues = []
    next_token = None
    
    while True:
        if next_token:
            response = connect.list_queues(
                InstanceId=instance_id,
                QueueTypes=['STANDARD'],
                NextToken=next_token,
                MaxResults=100
            )
        else:
            response = connect.list_queues(
                InstanceId=instance_id,
                QueueTypes=['STANDARD'],
                MaxResults=100
            )
        
        queues.extend(response.get('QueueSummaryList', []))
        
        next_token = response.get('NextToken')
        if not next_token:
            break
    
    return queues

def list_users(instance_id):
    """List all users for a Connect instance"""
    
    users = []
    next_token = None
    
    while True:
        if next_token:
            response = connect.list_users(
                InstanceId=instance_id,
                NextToken=next_token,
                MaxResults=100
            )
        else:
            response = connect.list_users(
                InstanceId=instance_id,
                MaxResults=100
            )
        
        users.extend(response.get('UserSummaryList', []))
        
        next_token = response.get('NextToken')
        if not next_token:
            break
    
    return users

def process_instance(instance, instance_records, current_time):
    """Process a Connect instance and prepare a record for Timestream"""
    
    # Extract instance data
    instance_id = instance.get('Id', 'unknown')
    instance_arn = instance.get('Arn', 'unknown')
    
    # Prepare dimensions for the instance record
    dimensions = [
        {'Name': 'InstanceId', 'Value': instance_id},
        {'Name': 'InstanceType', 'Value': instance.get('InstanceType', 'unknown')}
    ]
    
    # Prepare measures for the instance record
    measures = []
    
    # Add instance information
    measures.append({
        'Name': 'InstanceARN',
        'Value': instance_arn,
        'Type': 'VARCHAR'
    })
    
    measures.append({
        'Name': 'InstanceAlias',
        'Value': instance.get('InstanceAlias', ''),
        'Type': 'VARCHAR'
    })
    
    measures.append({
        'Name': 'CreatedTime',
        'Value': instance.get('CreatedTime', ''),
        'Type': 'VARCHAR'
    })
    
    # Add service role
    if 'ServiceRole' in instance:
        measures.append({
            'Name': 'ServiceRole',
            'Value': instance.get('ServiceRole', ''),
            'Type': 'VARCHAR'
        })
    
    # Add status
    if 'InstanceStatus' in instance:
        measures.append({
            'Name': 'InstanceStatus',
            'Value': instance.get('InstanceStatus', ''),
            'Type': 'VARCHAR'
        })
    
    # Create the record for the instance
    instance_record = {
        'Dimensions': dimensions,
        'MeasureName': 'Instance',
        'MeasureValueType': 'MULTI',
        'MeasureValues': measures,
        'Time': current_time
    }
    
    # Add the record to the batch
    instance_records.append(instance_record)

def process_queue(instance_id, queue, queue_records, current_time):
    """Process a Connect queue and prepare a record for Timestream"""
    
    # Extract queue data
    queue_id = queue.get('Id', 'unknown')
    queue_arn = queue.get('Arn', 'unknown')
    
    # Get detailed queue information
    try:
        queue_detail = connect.describe_queue(
            InstanceId=instance_id,
            QueueId=queue_id
        )
    except Exception as e:
        print(f"Error getting queue details for {queue_id}: {str(e)}")
        queue_detail = {'Queue': queue}
    
    queue_data = queue_detail.get('Queue', {})
    
    # Prepare dimensions for the queue record
    dimensions = [
        {'Name': 'InstanceId', 'Value': instance_id},
        {'Name': 'QueueId', 'Value': queue_id}
    ]
    
    # Prepare measures for the queue record
    measures = []
    
    # Add queue information
    measures.append({
        'Name': 'QueueARN',
        'Value': queue_arn,
        'Type': 'VARCHAR'
    })
    
    measures.append({
        'Name': 'QueueName',
        'Value': queue_data.get('Name', ''),
        'Type': 'VARCHAR'
    })
    
    measures.append({
        'Name': 'QueueDescription',
        'Value': queue_data.get('Description', ''),
        'Type': 'VARCHAR'
    })
    
    # Add queue type
    if 'QueueType' in queue_data:
        measures.append({
            'Name': 'QueueType',
            'Value': queue_data.get('QueueType', ''),
            'Type': 'VARCHAR'
        })
    
    # Add queue status
    if 'Status' in queue_data:
        measures.append({
            'Name': 'QueueStatus',
            'Value': queue_data.get('Status', ''),
            'Type': 'VARCHAR'
        })
    
    # Add maximum contacts
    if 'MaxContacts' in queue_data:
        measures.append({
            'Name': 'MaxContacts',
            'Value': str(queue_data.get('MaxContacts', 0)),
            'Type': 'BIGINT'
        })
    
    # Create the record for the queue
    queue_record = {
        'Dimensions': dimensions,
        'MeasureName': 'Queue',
        'MeasureValueType': 'MULTI',
        'MeasureValues': measures,
        'Time': current_time
    }
    
    # Add the record to the batch
    queue_records.append(queue_record)

def process_user(instance_id, user, user_records, current_time):
    """Process a Connect user and prepare a record for Timestream"""
    
    # Extract user data
    user_id = user.get('Id', 'unknown')
    user_arn = user.get('Arn', 'unknown')
    
    # Get detailed user information
    try:
        user_detail = connect.describe_user(
            InstanceId=instance_id,
            UserId=user_id
        )
    except Exception as e:
        print(f"Error getting user details for {user_id}: {str(e)}")
        user_detail = {'User': user}
    
    user_data = user_detail.get('User', {})
    
    # Prepare dimensions for the user record
    dimensions = [
        {'Name': 'InstanceId', 'Value': instance_id},
        {'Name': 'UserId', 'Value': user_id}
    ]
    
    # Add routing profile information if available
    if 'RoutingProfileId' in user_data:
        dimensions.append({
            'Name': 'RoutingProfileId',
            'Value': user_data.get('RoutingProfileId', '')
        })
    
    # Prepare measures for the user record
    measures = []
    
    # Add user information
    measures.append({
        'Name': 'UserARN',
        'Value': user_arn,
        'Type': 'VARCHAR'
    })
    
    measures.append({
        'Name': 'Username',
        'Value': user_data.get('Username', ''),
        'Type': 'VARCHAR'
    })
    
    # Add identity information if available
    if 'IdentityInfo' in user_data:
        identity = user_data.get('IdentityInfo', {})
        
        if 'FirstName' in identity:
            measures.append({
                'Name': 'FirstName',
                'Value': identity.get('FirstName', ''),
                'Type': 'VARCHAR'
            })
        
        if 'LastName' in identity:
            measures.append({
                'Name': 'LastName',
                'Value': identity.get('LastName', ''),
                'Type': 'VARCHAR'
            })
        
        if 'Email' in identity:
            measures.append({
                'Name': 'Email',
                'Value': identity.get('Email', ''),
                'Type': 'VARCHAR'
            })
    
    # Add phone type if available
    if 'PhoneConfig' in user_data:
        phone_config = user_data.get('PhoneConfig', {})
        
        if 'PhoneType' in phone_config:
            measures.append({
                'Name': 'PhoneType',
                'Value': phone_config.get('PhoneType', ''),
                'Type': 'VARCHAR'
            })
    
    # Add user hierarchies if available
    if 'HierarchyGroupId' in user_data:
        measures.append({
            'Name': 'HierarchyGroupId',
            'Value': user_data.get('HierarchyGroupId', ''),
            'Type': 'VARCHAR'
        })
    
    # Create the record for the user
    user_record = {
        'Dimensions': dimensions,
        'MeasureName': 'User',
        'MeasureValueType': 'MULTI',
        'MeasureValues': measures,
        'Time': current_time
    }
    
    # Add the record to the batch
    user_records.append(user_record)

def write_records_to_timestream(table_name, records):
    """Write a batch of records to the specified Timestream table"""
    
    try:
        # Split records into chunks of 100 (Timestream limit)
        chunk_size = 100
        for i in range(0, len(records), chunk_size):
            chunk = records[i:i + chunk_size]
            
            response = timestream_write.write_records(
                DatabaseName=database_name,
                TableName=table_name,
                Records=chunk,
                CommonAttributes={}
            )
            
            print(f"Successfully wrote {len(chunk)} records to table {table_name}")
            
    except Exception as e:
        print(f"Error writing to Timestream: {str(e)}")
        raise e