# Amazon Timestream Real-time Monitoring

This document describes the real-time monitoring capabilities added to the AWS Connect Analytics Pipeline using Amazon Timestream.

## Overview

Amazon Timestream is a fast, scalable, fully managed time series database service for IoT and operational applications that makes it easy to store and analyze trillions of time series data points per day. The Connect Analytics Pipeline uses Timestream to provide real-time monitoring of:

1. Agent events and states
2. Contact events
3. Instance, queue, and user data

This complements the historical analytics capabilities provided by S3, Glue, and Athena by enabling real-time dashboards and alerts.

## Architecture

The real-time monitoring architecture consists of these main components:

```
                                      ┌─────────────────┐
                                      │                 │
                                      │ Amazon Connect  │
                                      │                 │
                                      └────────┬────────┘
                                               │
                                               ▼
                                      ┌─────────────────┐
┌────────────────┐                    │                 │
│                │◄───Lambda────────┐ │ Kinesis Stream  │◄────┐
│   Timestream   │                  │ │                 │     │
│                │◄─────────────────┘ └────────┬────────┘     │
└───────┬────────┘                             │              │
        │                                      ▼              │
        │                             ┌─────────────────┐     │
        │                             │                 │     │
        │                             │EventBridge Rule │     │
        │                             └────────┬────────┘     │
        │                                      │              │
        ▼                                      ▼              │
┌────────────────┐                    ┌─────────────────┐     │
│                │                    │                 │     │
│    Grafana     │                    │EventBridge      │     │
│                │                    │  Scheduler      │     │
└────────────────┘                    └────────┬────────┘     │
                                               │              │
                                               └──────────────┘
```

## Data Collection

The system collects three types of data:

1. **Agent Events** - Processed from the Kinesis stream
   - Agent state changes (Available, On Call, After Call Work, etc.)
   - Login/logout events
   - Status duration tracking

2. **Contact Events** - Processed from Amazon Connect EventBridge events
   - Contact initiation
   - Queue transfers
   - Agent connections
   - Contact termination

3. **Instance Data** - Collected periodically via EventBridge Scheduler
   - Queue metrics (agents online, available)
   - User information
   - Instance configuration

## Timestream Tables

The following tables are created in the Timestream database:

| Table Name | Description | Data Source |
|------------|-------------|------------|
| AgentEvent | Stores agent state change events | Kinesis stream |
| AgentEvent_Contact | Links agent events to contacts | Kinesis stream |
| ContactEvent | Stores contact lifecycle events | EventBridge |
| Instance | Stores Connect instance metadata | Lambda (scheduled) |
| Queue | Stores queue configuration and metrics | Lambda (scheduled) |
| User | Stores user/agent information | Lambda (scheduled) |

## Data Retention

Timestream has a two-tier storage architecture:

1. **Memory Store** - High-performance storage for recent data (25 hours)
2. **Magnetic Store** - Cost-optimized storage for historical data (365 days)

Data automatically moves from Memory Store to Magnetic Store based on the configured retention period.

## Grafana Integration

Pre-built Grafana dashboards are provided for monitoring:

1. **Agent Events Dashboard** - Displays agent state changes, login status, and activity metrics
2. **Contact Events Dashboard** - Shows contact flow through the system including queue time, agent handling, and disposition

## Querying Timestream Data

You can directly query Timestream data using the AWS Timestream console or through the Grafana dashboards. Here are some example queries:

### Query Agent States

```sql
SELECT agent_id, state, duration
FROM "connect-analytics"."AgentEvent"
WHERE time BETWEEN ago(1h) AND now()
ORDER BY time DESC
```

### Query Contact Metrics

```sql
SELECT contact_id, queue_time, handle_time, after_call_work_time
FROM "connect-analytics"."ContactEvent"
WHERE time BETWEEN ago(24h) AND now()
```

### Query Queue Metrics

```sql
SELECT queue_name, agents_available, contacts_in_queue
FROM "connect-analytics"."Queue"
WHERE time BETWEEN ago(4h) AND now()
ORDER BY time DESC
```

## Region Compatibility

Amazon Timestream is not available in all AWS regions. Currently, it is supported in:

- us-east-1 (N. Virginia)
- us-east-2 (Ohio)
- us-west-2 (Oregon)
- eu-west-1 (Ireland)
- ap-northeast-1 (Tokyo)
- ap-southeast-2 (Sydney)
- eu-central-1 (Frankfurt)

This Connect Analytics Pipeline uses the eu-west-1 (Ireland) region for Timestream compatibility.

## Troubleshooting

### Missing Data in Timestream

1. **Check Lambda logs** in CloudWatch to ensure data is being processed correctly
2. **Verify Kinesis stream** is receiving data from Connect
3. **Check IAM permissions** on Lambda functions
4. **Validate EventBridge rules** are properly configured

### Dashboard Issues

1. **Ensure Timestream data source** is correctly configured in Grafana
2. **Check Timestream tables** exist and contain data
3. **Verify time range** in dashboard is appropriate for the data retention policy

## Further Reading

- [Amazon Timestream Developer Guide](https://docs.aws.amazon.com/timestream/latest/developerguide/what-is-timestream.html)
- [Timestream Query Language](https://docs.aws.amazon.com/timestream/latest/developerguide/querying.html)
- [Grafana Timestream Data Source](https://grafana.com/grafana/plugins/grafana-timestream-datasource/)
- [Amazon Connect Events](https://docs.aws.amazon.com/connect/latest/adminguide/monitoring-cloudwatch.html)