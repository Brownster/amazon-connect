#!/bin/bash
# Script to clean up and remove conflicting Timestream resources

echo "====================================================="
echo "  CLEANUP TIMESTREAM RESOURCES"
echo "====================================================="
echo "This script will help clean up any conflicting Timestream resources"
echo "that might be preventing successful deployment."
echo

# Check Timestream databases in eu-west-1
echo "Checking for existing Timestream databases in eu-west-1..."
DATABASES=$(aws timestream-write list-databases --region eu-west-1 2>/dev/null)
DB_STATUS=$?

if [ $DB_STATUS -eq 0 ]; then
  echo "Found existing Timestream databases:"
  echo "$DATABASES" | jq -r '.Databases[].DatabaseName'
  
  echo
  echo "Do you want to remove any of these databases? (y/n)"
  read -r CLEANUP
  
  if [[ "$CLEANUP" == "y" || "$CLEANUP" == "Y" ]]; then
    echo "Enter the database name to remove:"
    read -r DB_NAME
    
    # Check if database has tables
    TABLES=$(aws timestream-write list-tables --database-name "$DB_NAME" --region eu-west-1 2>/dev/null)
    
    if [ $? -eq 0 ]; then
      TABLE_COUNT=$(echo "$TABLES" | jq '.Tables | length')
      
      if [ "$TABLE_COUNT" -gt 0 ]; then
        echo "Database has $TABLE_COUNT tables. Removing tables first..."
        
        for TABLE in $(echo "$TABLES" | jq -r '.Tables[].TableName'); do
          echo "Removing table $TABLE..."
          aws timestream-write delete-table --database-name "$DB_NAME" --table-name "$TABLE" --region eu-west-1
          
          if [ $? -eq 0 ]; then
            echo "✅ Table $TABLE removed successfully."
          else
            echo "❌ Failed to remove table $TABLE."
          fi
        done
      fi
      
      # Now remove the database
      echo "Removing database $DB_NAME..."
      aws timestream-write delete-database --database-name "$DB_NAME" --region eu-west-1
      
      if [ $? -eq 0 ]; then
        echo "✅ Database $DB_NAME removed successfully."
      else
        echo "❌ Failed to remove database $DB_NAME."
      fi
    else
      echo "Failed to list tables in database $DB_NAME."
    fi
  fi
else
  echo "Either no Timestream databases exist or you don't have permission to list them."
  echo "Please run the test_timestream_permissions.sh script first."
fi

echo
echo "After cleanup, run the following to deploy Timestream resources:"
echo "./apply_timestream_module.sh"
echo
echo "====================================================="