# Prometheus and CloudWatch Monitoring for AWS Connect Analytics

This guide explains how to use the integrated Prometheus monitoring stack with CloudWatch metrics collection for the AWS Connect analytics pipeline.

## Architecture Overview

The monitoring stack includes the following components:

1. **Prometheus** - Time series database for metrics collection
2. **Node Exporter** - System metrics collector for the EC2 instance
3. **Yet Another CloudWatch Exporter (YACE)** - CloudWatch metrics collector
4. **Grafana** - Visualization platform with Athena and Prometheus datasources

The setup automatically collects both system metrics from the EC2 instance and CloudWatch metrics from AWS Connect, Kinesis, and other AWS services.

## Accessing the Monitoring Tools

### Prometheus Web UI

Access the Prometheus web UI through your browser:
```
http://<grafana_public_ip>:9090
```

This interface allows you to:
- Query metrics using PromQL
- View graphs of metrics data
- Explore available metrics
- Check targets and their status

### Grafana Dashboards

Grafana can now use both Athena (for querying the data lake) and Prometheus (for monitoring metrics):
```
http://<grafana_public_ip>:3000
```

## Available Metrics

The monitoring stack collects the following metrics:

### AWS Connect Metrics
- `aws_connect_CallsPerInterval_Sum` - Total number of calls in a period
- `aws_connect_ContactFlowErrors_Sum` - Contact flow execution errors
- `aws_connect_MissedCalls_Sum` - Calls that weren't answered
- `aws_connect_ConcurrentCalls_Maximum` - Peak concurrent calls
- `aws_connect_ConcurrentCallsPercentage_Maximum` - Percentage of concurrent call quota used
- `aws_connect_ThrottledCalls_Sum` - Calls throttled due to capacity limits

### Kinesis Stream Metrics
- `aws_kinesis_stream_IncomingRecords_Sum` - Records received by the stream
- `aws_kinesis_stream_IncomingBytes_Sum` - Bytes received by the stream
- `aws_kinesis_stream_GetRecords_IteratorAgeMilliseconds_Maximum` - Age of the oldest record in the stream
- `aws_kinesis_stream_ReadProvisionedThroughputExceeded_Sum` - Read throttling events

### System Metrics
- `node_cpu_seconds_total` - CPU usage of the EC2 instance
- `node_memory_MemAvailable_bytes` - Available memory
- `node_filesystem_avail_bytes` - Available disk space
- `node_network_receive_bytes_total` - Network traffic received
- `node_network_transmit_bytes_total` - Network traffic sent

## Creating Dashboards

### Connect Monitoring Dashboard

You can create a Connect monitoring dashboard by:

1. In Grafana, click "Create" > "Dashboard"
2. Add a panel
3. Select "Prometheus" as the data source
4. Use PromQL queries like:
   ```
   # Concurrent calls over time
   aws_connect_ConcurrentCalls_Maximum
   
   # Missed calls rate
   rate(aws_connect_MissedCalls_Sum[5m])
   ```

### Data Pipeline Monitoring Dashboard

Create a data pipeline monitoring dashboard using:
```
# Kinesis incoming records
rate(aws_kinesis_stream_IncomingRecords_Sum[5m])

# Iterator age (processing lag) in seconds
aws_kinesis_stream_GetRecords_IteratorAgeMilliseconds_Maximum / 1000
```

## Customizing the Monitoring Configuration

### Adding More CloudWatch Metrics

To add additional CloudWatch metrics:

1. SSH into the EC2 instance:
   ```bash
   ssh -i grafana-key ec2-user@<grafana_public_ip>
   ```

2. Edit the YACE configuration file:
   ```bash
   sudo nano /home/ec2-user/monitoring/yace/config/yace.yml
   ```

3. Add your desired metrics following the existing pattern in the file

4. Restart the YACE service:
   ```bash
   sudo /home/ec2-user/scripts/update_monitoring.sh restart-yace
   ```

### Modifying Prometheus Settings

To adjust Prometheus configuration:

1. Edit the Prometheus configuration file:
   ```bash
   sudo nano /home/ec2-user/monitoring/prometheus/config/prometheus.yml
   ```

2. Make your changes (add scrape targets, adjust settings)

3. Reload the Prometheus configuration:
   ```bash
   sudo /home/ec2-user/scripts/update_monitoring.sh reload-prometheus
   ```

## Troubleshooting

### No CloudWatch Metrics Appearing

If CloudWatch metrics are not appearing in Prometheus:

1. Check the IAM permissions for the EC2 instance
2. Verify the YACE configuration is correct
3. Examine the YACE logs:
   ```bash
   docker logs yace
   ```

### Prometheus Connectivity Issues

If Prometheus cannot be accessed:

1. Check the security group for the EC2 instance
2. Verify Prometheus is running:
   ```bash
   docker ps | grep prometheus
   ```
3. Restart the monitoring stack if needed:
   ```bash
   sudo /home/ec2-user/scripts/update_monitoring.sh restart-all
   ```

## Performance Considerations

The monitoring stack is configured to run on a t3.small instance, which should be sufficient for a test environment. However, monitor the resource usage and consider the following adjustments if needed:

1. Increase the scrape interval to reduce CPU usage:
   - Edit the `scrape_interval` in `/home/ec2-user/monitoring/prometheus/config/prometheus.yml`
   - Default is 60 seconds, can be increased for lower resource usage

2. Reduce the retention period to save disk space:
   - The default retention is 15 days
   - Can be adjusted in the docker-compose file's Prometheus command line arguments