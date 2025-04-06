# AWS Connect Real-Time Monitoring Integration Plan

## Overview
This document outlines the integration strategy for combining the existing AWS Connect analytics pipeline (CTR data to S3, Glue, and Athena) with a real-time monitoring system using Amazon Timestream, creating a comprehensive solution with both historical and real-time capabilities.

## Architecture Diagram
```
                                      ┌─────────────────┐
                                      │                 │
                                      │ Amazon Connect  │
                                      │                 │
                                      └────────┬────────┘
                                               │
                                               ▼
                                      ┌─────────────────┐
                                      │                 │
                                      │ Kinesis Stream  │
                                      │                 │
                                      └────────┬────────┘
                                               │
                    ┌──────────────────────────┴──────────────────────────┐
                    │                                                      │
                    ▼                                                      ▼
         ┌─────────────────┐                                    ┌─────────────────┐
         │                 │                                    │                 │
         │ Kinesis Firehose│                                    │ Lambda Functions│
         │                 │                                    │                 │
         └────────┬────────┘                                    └────────┬────────┘
                  │                                                      │
                  ▼                                                      ▼
         ┌─────────────────┐                                    ┌─────────────────┐
         │                 │                                    │                 │
         │     S3 Bucket   │                                    │    Timestream   │
         │                 │                                    │                 │
         └────────┬────────┘                                    └────────┬────────┘
                  │                                                      │
                  ▼                                                      ▼
         ┌─────────────────┐                                    ┌─────────────────┐
         │ Glue Crawler &  │                                    │                 │
         │   Catalog       │                                    │     Grafana     │
         └────────┬────────┘                                    │                 │
                  │                                             └─────────────────┘
                  ▼                                                      ▲
         ┌─────────────────┐                                             │
         │                 │                                    ┌─────────────────┐
         │     Athena      ├────────────────────────────────────▶ Athena Plugin  │
         │                 │                                    └─────────────────┘
         └─────────────────┘
```

## Integration Strategy

### 1. Single Kinesis Stream for Dual-Purpose
- Use existing Kinesis stream `connect-ctr-stream` as the single source of truth for CTR data
- Configure both Firehose (for S3/Athena) and Lambda functions (for Timestream) to consume from the same stream
- This eliminates data duplication and ensures consistency between historical and real-time analytics

### 2. Modify the IAM Roles and Policies
- Update the IAM roles to include permissions for both processing paths
- Ensure Lambda functions have appropriate permissions to read from the shared Kinesis stream

### 3. Timestream Database Implementation
- Create Timestream database and tables in the eu-west-2 (London) region
- Configure Lambda functions to process events from Kinesis and write to Timestream

### 4. Grafana Configuration Updates
- Configure Grafana with both Athena and Timestream data sources
- Create dashboards that merge historical data (Athena) and real-time metrics (Timestream)

## Implementation Steps

### 1. Prepare Terraform Modules
- Create a new module `terraform/timestream/` for the Timestream resources
- Add a new variable to existing Kinesis module to allow other services to access the stream

### 2. Create Timestream Resources
- Implement Timestream database and tables
- Set appropriate retention periods (memory store and magnetic store)
- Configure KMS encryption

### 3. Implement Lambda Functions
- Create Lambda functions for processing different event types
- Configure proper event mappings from Kinesis
- Implement error handling and retry logic

### 4. Extend IAM Permissions
- Update existing policies to include Timestream access
- Create new IAM roles for Lambda functions

### 5. Configure EventBridge
- Implement rules for Contact Events
- Set up scheduler for periodic data collection

### 6. Update Grafana Configuration
- Install and configure Timestream data source
- Create unified dashboards combining historical and real-time data

## Note on Lambda Code
The Lambda functions need Python code for:
- Processing agent events from Kinesis (`persist_agent_event.py`)
- Handling contact events from EventBridge (`persist_contact_event.py`)
- Collecting instance data periodically (`persist_instance_data.py`)

## Benefits of This Integration
- Historical data analysis through Athena (trends, patterns, compliance)
- Real-time operational metrics through Timestream (current state, alerts)
- Single data capture path minimizes issues with data inconsistency
- Unified visualization in Grafana provides complete operational picture