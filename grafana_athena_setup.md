# Setting Up Grafana with Athena Datasource

This guide walks you through setting up and configuring the Athena datasource plugin in your Grafana instance.

## 1. Install the Athena Plugin

### Using the Grafana UI
1. Log in to your Grafana instance at `http://<grafana_public_ip>:3000` with the admin credentials
2. Navigate to **Configuration** (gear icon) > **Plugins**
3. Search for "Athena"
4. Click on the "AWS Athena" plugin
5. Click the "Install" button
6. Restart Grafana after installation (you can do this via SSH)

### Using SSH to Install Plugin (Manual method)
If the plugin isn't available in the UI or you prefer command-line installation:

1. SSH into your Grafana instance:
   ```bash
   ssh -i grafana-key ec2-user@<grafana_public_ip>
   ```

2. Install the plugin using the grafana-cli:
   ```bash
   docker exec -it grafana grafana-cli plugins install grafana-athena-datasource
   ```

3. Restart the Grafana container:
   ```bash
   cd ~/grafana
   docker-compose restart
   ```

## 2. Configure the Athena Datasource

1. In the Grafana UI, go to **Configuration** > **Data Sources**
2. Click "Add data source"
3. Search for and select "Athena"
4. Configure the following settings:

   **Auth Provider**: Select "EC2 Instance IAM Role (same-origin)" - this uses the IAM role attached to your EC2 instance

   **Default Region**: `eu-west-2` (or your AWS region)
   
   **Catalog**: `AwsDataCatalog`
   
   **Database**: `connect_ctr_database` (from Terraform output)
   
   **Workgroup**: `connect-analytics`
   
   **Output Location**: `s3://connect-analytics-athena-results-XXXXX/output/` (use your specific bucket name from Terraform output)

5. Click "Save & Test" to verify the connection

## 3. Creating Your First Athena Query in Grafana

1. Navigate to **Explore** (compass icon)
2. Select the Athena datasource you just configured
3. Use the query builder or enter a custom SQL query, for example:
   ```sql
   SELECT 
     Channel,
     InitiationMethod,
     DisconnectReason,
     COUNT(*) as ContactCount
   FROM connect_ctr_database.connect_ctr_data  
   GROUP BY Channel, InitiationMethod, DisconnectReason
   ```

4. Click "Run Query" to test

## 4. Creating a Dashboard

1. Navigate to **Dashboards** (four squares icon) > **+ New Dashboard**
2. Click "+ Add new panel"
3. Select your Athena datasource
4. Create your query and configure the visualization
5. Click "Apply" to add the panel to your dashboard
6. Add additional panels as needed
7. Save the dashboard with a meaningful name

## 5. Sample Queries for Amazon Connect CTR Data

### Contact Volume by Channel
```sql
SELECT 
  Channel, 
  COUNT(*) as ContactCount
FROM connect_ctr_database.connect_ctr_data
GROUP BY Channel
```

### Average Queue Time by Queue
```sql
SELECT 
  Queue.QueueName, 
  AVG(Queue.Duration) as AvgQueueDuration
FROM connect_ctr_database.connect_ctr_data
GROUP BY Queue.QueueName
ORDER BY AvgQueueDuration DESC
```

### Agent Performance
```sql
SELECT 
  AgentInfo.AgentId,
  Attributes.AgentName,
  COUNT(*) as ContactCount,
  AVG(AgentInfo.AgentInteractionDuration) as AvgHandleTime
FROM connect_ctr_database.connect_ctr_data
GROUP BY AgentInfo.AgentId, Attributes.AgentName
ORDER BY ContactCount DESC
```

### Contact Resolution Rate
```sql
SELECT 
  Attributes.Resolution,
  COUNT(*) as ContactCount,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) as Percentage
FROM connect_ctr_database.connect_ctr_data
GROUP BY Attributes.Resolution
```

## Troubleshooting

### Cannot connect to Athena
1. Verify the IAM role has the correct permissions
2. Check that your VPC security groups allow outbound traffic
3. Ensure the workgroup and database names are correct

### No data in queries
1. Verify data is flowing through your pipeline:
   - Check your S3 bucket for data
   - Run the Glue crawler manually if needed
   - Try querying directly in the Athena console

### Plugin not installing
1. Check Grafana logs:
   ```bash
   docker exec -it grafana tail -f /var/log/grafana/grafana.log
   ```
2. Ensure Grafana has internet access to download plugins