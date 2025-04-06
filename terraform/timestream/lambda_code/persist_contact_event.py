import json
import os
import boto3
import time
from datetime import datetime

# Initialize Timestream client
timestream_write = boto3.client('timestream-write', 
                               region_name=os.environ.get('TIMESTREAM_REGION', 'eu-west-2'))
database_name = os.environ.get('TIMESTREAM_DATABASE_NAME', 'connect-analytics')

def lambda_handler(event, context):
    """
    Process contact events from EventBridge and write to Timestream
    
    This Lambda processes Connect contact events from EventBridge
    and persists them to the Timestream ContactEvent table.
    """
    
    print(f"Processing event: {json.dumps(event)}")
    
    # Ensure this is a Connect Contact Event
    if event.get('source') != 'aws.connect' or event.get('detail-type') != 'Amazon Connect Contact Event':
        print(f"Ignoring non-Connect contact event")
        return {
            'statusCode': 200,
            'body': 'Not a Connect contact event'
        }
    
    # Get the contact details from the event
    detail = event.get('detail', {})
    
    # Records for the contact event table
    contact_event_records = []
    
    try:
        # Process the contact event
        process_contact_event(detail, contact_event_records)
        
        # Write records to Timestream (if any)
        if contact_event_records:
            write_records_to_timestream("ContactEvent", contact_event_records)
        
    except Exception as e:
        print(f"Error processing event: {str(e)}")
        raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps('Processed contact event successfully')
    }

def process_contact_event(detail, contact_event_records):
    """Process a contact event and prepare records for Timestream"""
    
    # Get current time for the record
    current_time = str(int(time.time() * 1000))
    
    # Extract common fields
    contact_id = detail.get('ContactId', 'unknown')
    instance_id = detail.get('InstanceArn', 'unknown').split('/')[-1]
    channel = detail.get('Channel', 'unknown')
    
    # Prepare dimensions for the contact event record
    dimensions = [
        {'Name': 'ContactId', 'Value': contact_id},
        {'Name': 'InstanceId', 'Value': instance_id},
        {'Name': 'Channel', 'Value': channel},
        {'Name': 'EventType', 'Value': detail.get('EventType', 'unknown')}
    ]
    
    # Add InitiationMethod if available
    if 'InitiationMethod' in detail:
        dimensions.append({'Name': 'InitiationMethod', 'Value': detail.get('InitiationMethod', 'unknown')})
    
    # Prepare measures for the contact event record
    measures = []
    
    # Add ContactEventTimestamp
    if 'EventTimestamp' in detail:
        measures.append({
            'Name': 'ContactEventTimestamp',
            'Value': detail.get('EventTimestamp', ''),
            'Type': 'VARCHAR'
        })
    
    # Add InitiationTimestamp if available
    if 'InitiationTimestamp' in detail:
        measures.append({
            'Name': 'InitiationTimestamp',
            'Value': detail.get('InitiationTimestamp', ''),
            'Type': 'VARCHAR'
        })
    
    # Add DisconnectTimestamp if available
    if 'DisconnectTimestamp' in detail:
        measures.append({
            'Name': 'DisconnectTimestamp',
            'Value': detail.get('DisconnectTimestamp', ''),
            'Type': 'VARCHAR'
        })
    
    # Add Queue information if available
    if 'Queue' in detail:
        queue = detail.get('Queue', {})
        
        # Add queue name
        if 'Name' in queue:
            measures.append({
                'Name': 'QueueName',
                'Value': queue.get('Name', ''),
                'Type': 'VARCHAR'
            })
        
        # Add queue ARN
        if 'ARN' in queue:
            measures.append({
                'Name': 'QueueARN',
                'Value': queue.get('ARN', ''),
                'Type': 'VARCHAR'
            })
        
        # Add queue info timestamps
        if 'EnqueueTimestamp' in queue:
            measures.append({
                'Name': 'EnqueueTimestamp',
                'Value': queue.get('EnqueueTimestamp', ''),
                'Type': 'VARCHAR'
            })
        
        if 'DequeueTimestamp' in queue:
            measures.append({
                'Name': 'DequeueTimestamp',
                'Value': queue.get('DequeueTimestamp', ''),
                'Type': 'VARCHAR'
            })
    
    # Add Agent information if available
    if 'Agent' in detail:
        agent = detail.get('Agent', {})
        
        # Add agent ARN
        if 'ARN' in agent:
            measures.append({
                'Name': 'AgentARN',
                'Value': agent.get('ARN', ''),
                'Type': 'VARCHAR'
            })
        
        # Add agent info timestamps
        if 'ConnectedToAgentTimestamp' in agent:
            measures.append({
                'Name': 'ConnectedToAgentTimestamp',
                'Value': agent.get('ConnectedToAgentTimestamp', ''),
                'Type': 'VARCHAR'
            })
    
    # Add CustomerEndpoint information if available
    if 'CustomerEndpoint' in detail:
        endpoint = detail.get('CustomerEndpoint', {})
        
        # Add endpoint address (anonymized if needed)
        if 'Address' in endpoint:
            measures.append({
                'Name': 'CustomerEndpointAddress',
                'Value': endpoint.get('Address', ''),
                'Type': 'VARCHAR'
            })
        
        # Add endpoint type
        if 'Type' in endpoint:
            measures.append({
                'Name': 'CustomerEndpointType',
                'Value': endpoint.get('Type', ''),
                'Type': 'VARCHAR'
            })
    
    # Add SystemEndpoint information if available
    if 'SystemEndpoint' in detail:
        endpoint = detail.get('SystemEndpoint', {})
        
        # Add endpoint address (anonymized if needed)
        if 'Address' in endpoint:
            measures.append({
                'Name': 'SystemEndpointAddress',
                'Value': endpoint.get('Address', ''),
                'Type': 'VARCHAR'
            })
        
        # Add endpoint type
        if 'Type' in endpoint:
            measures.append({
                'Name': 'SystemEndpointType',
                'Value': endpoint.get('Type', ''),
                'Type': 'VARCHAR'
            })
    
    # Create the record for the contact event
    contact_event_record = {
        'Dimensions': dimensions,
        'MeasureName': 'ContactEvent',
        'MeasureValueType': 'MULTI',
        'MeasureValues': measures,
        'Time': current_time
    }
    
    # Add the record to the batch
    contact_event_records.append(contact_event_record)

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