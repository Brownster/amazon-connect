#!/bin/bash
# Script to set up Athena and Glue permissions

echo "Setting up Athena and Glue permissions..."

# Create a temporary policy file
cat > /tmp/analytics_policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "athena:*",
                "glue:*",
                "s3:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Get current user
USER_NAME=$(aws iam get-user --query 'User.UserName' --output text)
POLICY_NAME="AnalyticsFullAccess-$(date +%s)"

# Attach policy to user
echo "Attaching Analytics policy to user $USER_NAME..."
aws iam put-user-policy \
  --user-name "$USER_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document file:///tmp/analytics_policy.json

if [ $? -eq 0 ]; then
  echo "✅ Successfully attached Analytics policy to user $USER_NAME"
  echo "Policy name: $POLICY_NAME"
  echo "Please wait 15 seconds for permissions to propagate..."
  sleep 15
else
  echo "❌ Failed to attach policy to user $USER_NAME"
fi

# Clean up
rm /tmp/analytics_policy.json

echo "Done."