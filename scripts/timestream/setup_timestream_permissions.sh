#!/bin/bash
# Script to set up proper Timestream permissions

echo "Setting up Timestream permissions..."

# Create a temporary policy file
cat > /tmp/timestream_policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "timestream:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:CreateKey",
                "kms:Decrypt",
                "kms:DescribeKey",
                "kms:EnableKeyRotation",
                "kms:GenerateDataKey",
                "kms:ListAliases",
                "kms:CreateAlias",
                "kms:PutKeyPolicy"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Get current user
USER_NAME=$(aws iam get-user --query 'User.UserName' --output text)
POLICY_NAME="TimestreamFullAccess-$(date +%s)"

# Attach policy to user
echo "Attaching Timestream policy to user $USER_NAME..."
aws iam put-user-policy \
  --user-name "$USER_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document file:///tmp/timestream_policy.json

if [ $? -eq 0 ]; then
  echo "✅ Successfully attached Timestream policy to user $USER_NAME"
  echo "Policy name: $POLICY_NAME"
  echo "Please wait 15 seconds for permissions to propagate..."
  sleep 15
else
  echo "❌ Failed to attach policy to user $USER_NAME"
fi

# Clean up
rm /tmp/timestream_policy.json

# Test permissions
echo "Testing Timestream permissions..."
aws timestream-write describe-endpoints --region eu-west-1

echo "Done."