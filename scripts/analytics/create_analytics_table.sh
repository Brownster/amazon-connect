#!/bin/bash
# Script to create and test Glue/Athena integration

cd "$(dirname "$0")" || exit 1
echo "Creating a sample table and testing Athena query execution..."

# Get database information
DATABASE=$(aws glue get-databases --region eu-west-2 --query "DatabaseList[0].Name" --output text)
ATHENA_WORKGROUP=$(aws athena list-work-groups --region eu-west-2 --query "WorkGroups[?Name!='primary'].Name" --output text)
RESULTS_BUCKET=$(aws s3 ls | grep connect | grep athena-results | awk '{print $NF}')

echo "Found database: $DATABASE"
echo "Found Athena workgroup: $ATHENA_WORKGROUP"
echo "Found results bucket: $RESULTS_BUCKET"

# Create a sample Glue table definition JSON
cat > /tmp/sample_table.json <<EOF
{
  "Name": "sample_contact_events",
  "Description": "Sample table for testing",
  "StorageDescriptor": {
    "Columns": [
      {
        "Name": "contact_id",
        "Type": "string"
      },
      {
        "Name": "timestamp",
        "Type": "timestamp"
      },
      {
        "Name": "agent_id",
        "Type": "string"
      },
      {
        "Name": "event_type",
        "Type": "string"
      }
    ],
    "Location": "s3://$RESULTS_BUCKET/sample_data/",
    "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
    "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
    "SerdeInfo": {
      "SerializationLibrary": "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe",
      "Parameters": {
        "field.delim": ","
      }
    }
  },
  "TableType": "EXTERNAL_TABLE"
}
EOF

# Create the table
echo "Creating sample table in Glue..."
aws glue create-table --database-name "$DATABASE" --table-input file:///tmp/sample_table.json --region eu-west-2

# Run an Athena query to verify
echo "Running Athena query to verify table exists..."
QUERY_ID=$(aws athena start-query-execution \
  --query-string "SHOW TABLES in $DATABASE" \
  --work-group "$ATHENA_WORKGROUP" \
  --result-configuration "OutputLocation=s3://$RESULTS_BUCKET/query_results/" \
  --region eu-west-2 \
  --query "QueryExecutionId" \
  --output text)

echo "Query ID: $QUERY_ID"
echo "Waiting for query to complete..."

# Wait for query to complete
for i in {1..10}; do
  STATUS=$(aws athena get-query-execution \
    --query-execution-id "$QUERY_ID" \
    --region eu-west-2 \
    --query "QueryExecution.Status.State" \
    --output text)
    
  echo "Query status: $STATUS"
  
  if [ "$STATUS" = "SUCCEEDED" ]; then
    break
  elif [ "$STATUS" = "FAILED" ]; then
    echo "Query failed!"
    aws athena get-query-execution --query-execution-id "$QUERY_ID" --region eu-west-2
    exit 1
  fi
  
  sleep 2
done

# Get query results
echo "Getting query results..."
aws athena get-query-results \
  --query-execution-id "$QUERY_ID" \
  --region eu-west-2

echo "Test complete!"