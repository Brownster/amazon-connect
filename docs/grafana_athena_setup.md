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

   **Auth Provider**: Select "AWS SDK Default" (this uses the IAM role attached to your EC2 instance)

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

## 5. Understanding and Using Partitioned Data

The CTR data is stored using a time-based partitioning scheme for improved performance:

```
connect-ctr-data/
├── year=2023/
│   └── month=12/
│       └── day=15/
│           └── hour=14/
│               └── data files
```

This structure allows for much more efficient queries when you include partition columns in your WHERE clause. Athena will only scan the partitions that match your criteria, significantly reducing query cost and improving performance.

### Using Partitions in Grafana Queries

When creating dashboards in Grafana that cover specific time periods, always include the partition columns in your queries. For example:

```sql
-- This query is EFFICIENT (uses partitions)
SELECT * 
FROM connect_ctr_database.connect_ctr_data 
WHERE year='2023' AND month='12' AND day='15'
LIMIT 100;
```

### Time Variables in Grafana

Grafana provides built-in time range variables that can be used to dynamically filter by partitions:

```sql
-- Using Grafana's time variables with partitions
SELECT *
FROM connect_ctr_database.connect_ctr_data
WHERE 
  year = CAST(DATE_FORMAT($__timeFrom, '%Y') AS VARCHAR) AND
  month = CAST(DATE_FORMAT($__timeFrom, '%m') AS VARCHAR) AND
  day BETWEEN CAST(DATE_FORMAT($__timeFrom, '%d') AS VARCHAR) AND CAST(DATE_FORMAT($__timeTo, '%d') AS VARCHAR)
```

## 6. Sample Queries for Amazon Connect CTR Data

### Contact Volume by Channel (Partition-Optimized)
```sql
SELECT 
  Channel, 
  COUNT(*) as ContactCount
FROM connect_ctr_database.connect_ctr_data
WHERE 
  year = CAST(DATE_FORMAT($__timeFrom, '%Y') AS VARCHAR) AND
  month = CAST(DATE_FORMAT($__timeFrom, '%m') AS VARCHAR) AND
  day BETWEEN CAST(DATE_FORMAT($__timeFrom, '%d') AS VARCHAR) AND CAST(DATE_FORMAT($__timeTo, '%d') AS VARCHAR)
GROUP BY Channel
```

### Average Queue Time by Queue
```sql
SELECT 
  Queue.QueueName, 
  AVG(Queue.Duration) as AvgQueueDuration
FROM connect_ctr_database.connect_ctr_data
WHERE 
  -- Add time partition filtering
  year = CAST(DATE_FORMAT($__timeFrom, '%Y') AS VARCHAR) AND
  month = CAST(DATE_FORMAT($__timeFrom, '%m') AS VARCHAR) AND
  day BETWEEN CAST(DATE_FORMAT($__timeFrom, '%d') AS VARCHAR) AND CAST(DATE_FORMAT($__timeTo, '%d') AS VARCHAR)
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
WHERE 
  -- Add time partition filtering
  year = CAST(DATE_FORMAT($__timeFrom, '%Y') AS VARCHAR) AND
  month = CAST(DATE_FORMAT($__timeFrom, '%m') AS VARCHAR) AND
  day BETWEEN CAST(DATE_FORMAT($__timeFrom, '%d') AS VARCHAR) AND CAST(DATE_FORMAT($__timeTo, '%d') AS VARCHAR)
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
WHERE 
  -- Add time partition filtering
  year = CAST(DATE_FORMAT($__timeFrom, '%Y') AS VARCHAR) AND
  month = CAST(DATE_FORMAT($__timeFrom, '%m') AS VARCHAR) AND
  day BETWEEN CAST(DATE_FORMAT($__timeFrom, '%d') AS VARCHAR) AND CAST(DATE_FORMAT($__timeTo, '%d') AS VARCHAR)
GROUP BY Attributes.Resolution
```

### Hourly Contact Volume Trend
```sql
SELECT 
  PARSE_DATETIME(CONCAT(year, '-', month, '-', day, ' ', hour, ':00:00'), 'yyyy-MM-dd HH:mm:ss') as hourly_timestamp,
  COUNT(*) as contact_count
FROM connect_ctr_database.connect_ctr_data
WHERE 
  year = CAST(DATE_FORMAT($__timeFrom, '%Y') AS VARCHAR) AND
  month = CAST(DATE_FORMAT($__timeFrom, '%m') AS VARCHAR) AND
  day BETWEEN CAST(DATE_FORMAT($__timeFrom, '%d') AS VARCHAR) AND CAST(DATE_FORMAT($__timeTo, '%d') AS VARCHAR)
GROUP BY year, month, day, hour
ORDER BY hourly_timestamp
```

## Troubleshooting

### Cannot connect to Athena
1. Verify the IAM role has the correct permissions
2. Check that your VPC security groups allow outbound traffic
3. Ensure the workgroup and database names are correct

### Error: User is not authorized to perform sts:AssumeRole
If you get an error like: "User: arn:aws:sts::XXXX:assumed-role/grafana-instance-role/i-XXXX is not authorized to perform: sts:AssumeRole"

1. Try changing the Auth Provider from "EC2 Instance IAM Role" to "AWS SDK Default"
2. If that doesn't work, SSH into the EC2 instance and verify the IAM role configuration:
   ```bash
   aws sts get-caller-identity
   ```
3. Ensure the IAM role has permission to access Athena and S3 resources

### No data in queries
1. Verify data is flowing through your pipeline:
   - Check your S3 bucket for data and confirm the partition structure
   - Run the Glue crawler manually if needed
   - Try querying directly in the Athena console

### Slow Queries or High Costs
1. Check if your queries are using partitions:
   - Always include partition columns (year, month, day) in your WHERE clauses
   - Use Grafana's time variables to dynamically filter partitions
   - In Athena console, check the "Data scanned" metric after running queries
   - Queries not using partitions might scan all data, resulting in high costs

### Partition-related Issues
1. If partitions aren't recognized:
   - Check that the Glue crawler has run recently
   - Verify the partition structure in S3 follows the correct format
   - Try running the query directly in Athena to identify partition issues
   - Use the `MSCK REPAIR TABLE connect_ctr_database.connect_ctr_data` command in Athena

### Plugin not installing
1. Check Grafana logs:
   ```bash
   docker exec -it grafana tail -f /var/log/grafana/grafana.log
   ```
2. Ensure Grafana has internet access to download plugins

### Dashboard Refresh Performance
1. If dashboards are slow to refresh:
   - Reduce the time range to query fewer partitions
   - Optimize your SQL queries with appropriate WHERE clauses
   - Consider creating dashboards for specific time periods instead of all-time views
   - Use daily or weekly aggregation tables for long-term trends