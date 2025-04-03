#!/usr/bin/env python3
import json
import time
import random
import uuid
import datetime
import boto3
from botocore.exceptions import ClientError

# Configuration
STREAM_NAME = "connect-ctr-stream"  # Update with your stream name
REGION = "eu-west-2"               # Update with your region
RECORD_COUNT = 100                 # Number of records to generate
BATCH_SIZE = 25                    # Records per batch
DELAY_BETWEEN_BATCHES = 1          # Seconds between batches

# Initialize AWS clients
kinesis_client = boto3.client('kinesis', region_name=REGION)

# Names for simulation
first_names = ["James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda", "William", "Elizabeth"]
last_names = ["Smith", "Johnson", "Williams", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor"]
agent_names = ["Alex Johnson", "Jamie Smith", "Casey Brown", "Morgan Lee", "Taylor Wilson", "Sam Davis"]
queues = ["GeneralQueue", "SalesQueue", "SupportQueue", "BillingQueue", "TechnicalQueue"]
phone_types = ["LANDLINE", "MOBILE", "VOIP"]
disconnect_reasons = ["CUSTOMER_DISCONNECT", "AGENT_DISCONNECT", "THIRD_PARTY_DISCONNECT", "TELECOM_PROBLEM"]
channels = ["VOICE", "CHAT", "TASK"]

# Generate random phone number
def generate_phone():
    return f"+44{random.randint(7000000000, 7999999999)}"

# Generate a random timestamp within the last 24 hours
def generate_timestamp():
    now = datetime.datetime.now()
    random_hours = random.randint(0, 24)
    random_minutes = random.randint(0, 59)
    random_seconds = random.randint(0, 59)
    timestamp = now - datetime.timedelta(hours=random_hours, minutes=random_minutes, seconds=random_seconds)
    return timestamp.strftime("%Y-%m-%dT%H:%M:%S.%fZ")

# Generate a random duration between 30 seconds and 20 minutes
def generate_duration():
    return random.randint(30, 1200)

# Generate a single CTR record
def generate_ctr_record():
    # Contact basics
    contact_id = str(uuid.uuid4())
    channel = random.choice(channels)
    
    # Create timestamps
    init_timestamp = generate_timestamp()
    init_dt = datetime.datetime.strptime(init_timestamp, "%Y-%m-%dT%H:%M:%S.%fZ")
    
    # Connected timestamp (0-2 minutes after init)
    connected_seconds = random.randint(0, 120)
    connected_dt = init_dt + datetime.timedelta(seconds=connected_seconds)
    connected_timestamp = connected_dt.strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    
    # Talk duration (0-15 minutes)
    agent_interaction_duration = random.randint(0, 900)
    
    # Disconnect timestamp
    disconnected_dt = connected_dt + datetime.timedelta(seconds=agent_interaction_duration)
    disconnected_timestamp = disconnected_dt.strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    
    # Queue duration (0-5 minutes)
    queue_duration = random.randint(0, 300)
    
    # Customer
    customer_first_name = random.choice(first_names)
    customer_last_name = random.choice(last_names)
    customer_phone = generate_phone()
    
    # Agent
    agent_id = f"agent-{random.randint(1000, 9999)}"
    agent_name = random.choice(agent_names)
    
    # Queue
    queue_name = random.choice(queues)
    
    # Base record
    record = {
        "AWSAccountId": "891612549865",  # Replace with your account ID
        "InstanceId": "6e4f36f4-1b28-4725-a407-79a31c76a9b8",  # Replace with your Connect instance ID
        "ContactId": contact_id,
        "Channel": channel,
        "InitiationTimestamp": init_timestamp,
        "ConnectedToSystemTimestamp": init_timestamp,
        "DisconnectTimestamp": disconnected_timestamp,
        "CustomerEndpoint": {
            "Type": random.choice(phone_types),
            "Address": customer_phone
        },
        "InitialContactId": contact_id,
        "InitiationMethod": "INBOUND",
        "DisconnectReason": random.choice(disconnect_reasons),
        "Queue": {
            "QueueName": queue_name,
            "QueueId": f"queue-{random.randint(1000, 9999)}",
            "EnqueueTimestamp": init_timestamp,
            "DequeueTimestamp": connected_timestamp,
            "Duration": queue_duration
        },
        "AgentInfo": {
            "AgentId": agent_id,
            "ConnectedToAgentTimestamp": connected_timestamp,
            "AgentInteractionDuration": agent_interaction_duration
        },
        "Recording": {
            "Status": "AVAILABLE" if random.random() > 0.2 else "UNAVAILABLE"
        },
        "CustomerVoiceActivity": {
            "TalkTime": random.randint(10, agent_interaction_duration - 10 if agent_interaction_duration > 10 else 1),
            "ListenTime": random.randint(10, agent_interaction_duration - 10 if agent_interaction_duration > 10 else 1)
        },
        "Attributes": {
            "CustomerFirstName": customer_first_name,
            "CustomerLastName": customer_last_name,
            "AgentName": agent_name,
            "Sentiment": random.choice(["Positive", "Neutral", "Negative"]),
            "Resolution": random.choice(["Resolved", "Escalated", "Follow-up", "Unresolved"])
        }
    }
    
    # Add channel-specific fields
    if channel == "VOICE":
        record["Recording"]["Location"] = f"s3://connect-recordings/voice/{contact_id}.wav"
    elif channel == "CHAT":
        record["Recording"]["Location"] = f"s3://connect-recordings/chat/{contact_id}.json"
        # Remove voice-specific fields
        del record["CustomerVoiceActivity"]
    elif channel == "TASK":
        # Tasks don't have recordings or voice activity
        del record["Recording"]
        del record["CustomerVoiceActivity"]
    
    return record

# Send records to Kinesis
def send_to_kinesis(records):
    try:
        # Prepare records for Kinesis
        kinesis_records = [
            {
                'Data': json.dumps(record),
                'PartitionKey': record['ContactId']
            } for record in records
        ]
        
        # Send to Kinesis
        response = kinesis_client.put_records(
            Records=kinesis_records,
            StreamName=STREAM_NAME
        )
        
        # Check for failures
        failed_count = response.get('FailedRecordCount', 0)
        if failed_count:
            print(f"Failed to send {failed_count} records")
        else:
            print(f"Successfully sent {len(records)} records to Kinesis")
            
        return response
    except ClientError as e:
        print(f"Error sending records to Kinesis: {e}")
        return None

# Main execution
def main():
    print(f"Generating {RECORD_COUNT} CTR records for stream {STREAM_NAME}")
    
    # Generate and send records in batches
    for i in range(0, RECORD_COUNT, BATCH_SIZE):
        batch_size = min(BATCH_SIZE, RECORD_COUNT - i)
        batch_records = [generate_ctr_record() for _ in range(batch_size)]
        
        print(f"Sending batch {i//BATCH_SIZE + 1} with {batch_size} records...")
        send_to_kinesis(batch_records)
        
        # Sleep between batches to avoid throttling
        if i + BATCH_SIZE < RECORD_COUNT:
            time.sleep(DELAY_BETWEEN_BATCHES)
    
    print(f"Completed sending {RECORD_COUNT} CTR records")

if __name__ == "__main__":
    main()