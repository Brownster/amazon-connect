#!/bin/bash
# Script to test Timestream permissions

echo "====================================================="
echo "  TESTING TIMESTREAM PERMISSIONS"
echo "====================================================="
echo

# Test Timestream endpoint access in eu-west-1
echo "Testing Timestream endpoint access in eu-west-1..."
aws timestream-write describe-endpoints --region eu-west-1
ENDPOINT_STATUS=$?

if [ $ENDPOINT_STATUS -eq 0 ]; then
  echo "✅ Timestream endpoint access is working."
else
  echo "❌ Timestream endpoint access failed."
  echo "Creating an inline policy to fix Timestream access..."
  
  # Create policy document
  cat > /tmp/timestream-full-access.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "timestream:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

  # Attach policy to current user
  USER_NAME=$(aws iam get-user --query 'User.UserName' --output text)
  aws iam put-user-policy \
    --user-name $USER_NAME \
    --policy-name TimestreamFullAccess \
    --policy-document file:///tmp/timestream-full-access.json
  
  if [ $? -eq 0 ]; then
    echo "✅ Added TimestreamFullAccess policy to user $USER_NAME"
    echo "Please wait 10-15 seconds for permissions to propagate..."
    sleep 15
    
    # Test endpoint access again
    echo "Testing Timestream endpoint access again..."
    aws timestream-write describe-endpoints --region eu-west-1
    if [ $? -eq 0 ]; then
      echo "✅ Timestream endpoint access is now working."
    else
      echo "❌ Timestream endpoint access still failed. Please check IAM configurations."
    fi
  else
    echo "❌ Failed to add TimestreamFullAccess policy to user $USER_NAME"
  fi
  
  # Clean up
  rm /tmp/timestream-full-access.json
fi

echo
echo "To continue with the Timestream module deployment:"
echo "./apply_timestream_module.sh"
echo
echo "====================================================="