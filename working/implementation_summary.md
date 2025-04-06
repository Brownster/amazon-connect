# Amazon Connect Real-time Monitoring Implementation

## Overview

We've implemented a comprehensive solution that enhances the existing AWS Connect analytics pipeline with Amazon Timestream for real-time monitoring. This integration allows for both historical analytics (via S3/Athena) and real-time operational monitoring (via Timestream) using a single Kinesis data stream as the source of truth.

## Components Implemented

1. **Timestream Database and Tables**
   - Created a Timestream database with six tables for different data types
   - Configured appropriate retention periods (25 hours in memory, 365 days in magnetic storage)
   - Set up KMS encryption for data security

2. **Lambda Functions for Data Processing**
   - `persist_agent_event.py`: Processes agent events from the Kinesis stream
   - `persist_contact_event.py`: Processes contact events from EventBridge
   - `persist_instance_data.py`: Periodically collects instance, queue, and agent metadata

3. **IAM Roles and Policies**
   - Created roles for Lambda functions with least privilege permissions
   - Added policies for Timestream access and Kinesis data consumption
   - Extended Grafana's IAM permissions to include Timestream queries

4. **Event Sources and Triggers**
   - Configured Kinesis stream as an event source for agent events
   - Set up EventBridge rule for contact events
   - Created EventBridge scheduler for periodic instance data collection

5. **Grafana Integration**
   - Added Timestream as a data source in Grafana
   - Enabled side-by-side querying of historical (Athena) and real-time (Timestream) data
   - Installed necessary plugins for visualization
   - Provisioned pre-built dashboards for agent and contact events monitoring
   - Configured automatic dashboard loading and organization

## Architecture Diagram

```
┌─────────────────┐
│                 │
│ Amazon Connect  │
│                 │
└───────┬─────────┘
        │
        ▼
┌─────────────────┐
│                 │
│ Kinesis Stream  │◄────┐
│(connect_ctr_stream)   │
└┬────────────────┬┘    │
 │                │     │
 ▼                ▼     │
┌─────────┐    ┌────────────────┐
│         │    │                │
│Firehose │    │Lambda Function │
│         │    │(Agent Events)  │
└────┬────┘    └────────┬───────┘
     │                  │
     ▼                  ▼
┌─────────┐    ┌────────────────┐
│         │    │                │
│   S3    │    │   Timestream   │◄────┐
│         │    │                │     │
└────┬────┘    └────────────────┘     │
     │                                │
     ▼                                │
┌─────────┐    ┌────────────────┐     │
│         │    │EventBridge Rule│     │
│  Glue   │    │(Contact Events)│     │
│         │    └────────┬───────┘     │
└────┬────┘             │             │
     │                  ▼             │
     ▼            ┌────────────────┐  │
┌─────────┐       │Lambda Function │  │
│         │       │(Contact Events)│  │
│ Athena  │       └────────┬───────┘  │
│         │                │          │
└────┬────┘                └──────────┘
     │                                │
     ▼                                ▼
┌──────────────────────────────────────┐
│                                      │
│             Grafana                  │
│                                      │
└──────────────────────────────────────┘
```

## Next Steps

1. **Refine Dashboards**
   - Customize the pre-built dashboards based on specific monitoring needs
   - Create additional dashboards for specific use cases or departments

2. **Set Up Alerts**
   - Configure Grafana alerts based on Timestream metrics
   - Set up notification channels for critical events

3. **Performance Tuning**
   - Monitor Lambda performance and adjust batch sizes if needed
   - Optimize Timestream query patterns

4. **Documentation**
   - Complete user documentation for the new dashboards
   - Create operations runbook for the real-time monitoring system

This implementation provides a solid foundation for enhanced AWS Connect monitoring, giving you both the deep historical analytics capabilities of Athena and the real-time operational insights from Timestream in a single unified system.