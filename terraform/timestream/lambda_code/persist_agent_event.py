import json
import base64
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
    Process agent events from Kinesis stream and write to Timestream
    
    This Lambda processes Connect CTR records containing agent events
    and persists them to Timestream tables.
    """
    
    print(f"Processing {len(event['Records'])} records")
    
    # Records for each table
    agent_event_records = []
    agent_event_contact_records = []
    
    # Process each record from Kinesis
    for record in event['Records']:
        try:
            # Decode and parse the payload
            payload = base64.b64decode(record['kinesis']['data']).decode('utf-8')
            data = json.loads(payload)
            
            # Check if this is a Connect CTR record with agent event data
            if 'Agent' in data and 'EventType' in data:
                process_agent_event(data, agent_event_records, agent_event_contact_records)
            
        except Exception as e:
            print(f"Error processing record: {str(e)}")
            continue
    
    # Write records to Timestream (if any)
    if agent_event_records:
        write_records_to_timestream("AgentEvent", agent_event_records)
    
    if agent_event_contact_records:
        write_records_to_timestream("AgentEvent_Contact", agent_event_contact_records)
    
    return {
        'statusCode': 200,
        'body': json.dumps(f'Processed {len(event["Records"])} records')
    }

def process_agent_event(data, agent_event_records, agent_event_contact_records):
    """Process a single agent event and prepare records for Timestream"""
    
    # Get current time for the record
    current_time = str(int(time.time() * 1000))
    
    # Prepare dimensions for the agent event record
    dimensions = [
        {'Name': 'AgentARN', 'Value': data.get('Agent', {}).get('ARN', 'unknown')},
        {'Name': 'InstanceId', 'Value': data.get('InstanceId', 'unknown')},
        {'Name': 'EventType', 'Value': data.get('EventType', 'unknown')},
        {'Name': 'EventTimestamp', 'Value': data.get('EventTimestamp', 'unknown')}
    ]
    
    # Add hierarchyPath dimensions if available
    if 'HierarchyPath' in data.get('Agent', {}):
        hierarchy = data.get('Agent', {}).get('HierarchyPath', {})
        for level, name in hierarchy.items():
            dimensions.append({'Name': f'Hierarchy{level}', 'Value': name})
    
    # Prepare measures for the agent event record
    measures = []
    
    # Add EventId as a measure
    measures.append({
        'Name': 'EventId',
        'Value': data.get('EventId', 'unknown'),
        'Type': 'VARCHAR'
    })
    
    # Add state reason if available
    if 'StateReason' in data:
        measures.append({
            'Name': 'StateReason', 
            'Value': data.get('StateReason', ''), 
            'Type': 'VARCHAR'
        })
    
    # Add agent status information if available
    if 'CurrentAgentSnapshot' in data:
        snapshot = data.get('CurrentAgentSnapshot', {})
        
        # Add agent configuration data
        if 'Configuration' in snapshot:
            config = snapshot.get('Configuration', {})
            
            # Add username
            if 'Username' in config:
                measures.append({
                    'Name': 'Username',
                    'Value': config.get('Username', ''),
                    'Type': 'VARCHAR'
                })
            
            # Add first and last name
            if 'FirstName' in config:
                measures.append({
                    'Name': 'FirstName',
                    'Value': config.get('FirstName', ''),
                    'Type': 'VARCHAR'
                })
            
            if 'LastName' in config:
                measures.append({
                    'Name': 'LastName',
                    'Value': config.get('LastName', ''),
                    'Type': 'VARCHAR'
                })
        
        # Add agent state information
        if 'AgentStatus' in snapshot:
            status = snapshot.get('AgentStatus', {})
            
            # Add state name
            if 'Name' in status:
                measures.append({
                    'Name': 'AgentStatusName',
                    'Value': status.get('Name', ''),
                    'Type': 'VARCHAR'
                })
            
            # Add state type
            if 'Type' in status:
                measures.append({
                    'Name': 'AgentStatusType',
                    'Value': status.get('Type', ''),
                    'Type': 'VARCHAR'
                })
            
            # Add state duration
            if 'Duration' in status:
                measures.append({
                    'Name': 'AgentStatusDuration',
                    'Value': str(status.get('Duration', 0)),
                    'Type': 'BIGINT'
                })
    
    # Create the record for the agent event
    agent_event_record = {
        'Dimensions': dimensions,
        'MeasureName': 'AgentEvent',
        'MeasureValueType': 'MULTI',
        'MeasureValues': measures,
        'Time': current_time
    }
    
    # Add the record to the batch
    agent_event_records.append(agent_event_record)
    
    # Process Contact information if available
    if 'Contacts' in data:
        for contact in data.get('Contacts', []):
            # Prepare dimensions for the agent event contact record
            contact_dimensions = [
                {'Name': 'AgentARN', 'Value': data.get('Agent', {}).get('ARN', 'unknown')},
                {'Name': 'InstanceId', 'Value': data.get('InstanceId', 'unknown')},
                {'Name': 'ContactId', 'Value': contact.get('ContactId', 'unknown')},
                {'Name': 'Channel', 'Value': contact.get('Channel', 'unknown')},
                {'Name': 'EventType', 'Value': data.get('EventType', 'unknown')}
            ]
            
            # Prepare measures for the agent event contact record
            contact_measures = []
            
            # Add state durations if available
            if 'StateStartTimestamp' in contact:
                contact_measures.append({
                    'Name': 'StateStartTimestamp',
                    'Value': contact.get('StateStartTimestamp', ''),
                    'Type': 'VARCHAR'
                })
            
            if 'State' in contact:
                contact_measures.append({
                    'Name': 'ContactState',
                    'Value': contact.get('State', ''),
                    'Type': 'VARCHAR'
                })
            
            if 'ConnectedToAgentTimestamp' in contact:
                contact_measures.append({
                    'Name': 'ConnectedToAgentTimestamp',
                    'Value': contact.get('ConnectedToAgentTimestamp', ''),
                    'Type': 'VARCHAR'
                })
            
            if 'Queue' in contact and 'Name' in contact['Queue']:
                contact_measures.append({
                    'Name': 'QueueName',
                    'Value': contact.get('Queue', {}).get('Name', ''),
                    'Type': 'VARCHAR'
                })
            
            # Create the record for the agent event contact
            agent_event_contact_record = {
                'Dimensions': contact_dimensions,
                'MeasureName': 'AgentEventContact',
                'MeasureValueType': 'MULTI',
                'MeasureValues': contact_measures,
                'Time': current_time
            }
            
            # Add the record to the batch
            agent_event_contact_records.append(agent_event_contact_record)

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