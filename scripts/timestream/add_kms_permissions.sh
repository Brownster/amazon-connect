#!/bin/bash
# Script to add KMS permissions

echo "Adding KMS permissions..."

# Create a temporary policy file
cat > /tmp/kms_policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# Get current user
USER_NAME=$(aws iam get-user --query 'User.UserName' --output text)
POLICY_NAME="KMSFullAccess-$(date +%s)"

# Attach policy to user
echo "Attaching KMS policy to user $USER_NAME..."
aws iam put-user-policy \
  --user-name "$USER_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document file:///tmp/kms_policy.json

if [ $? -eq 0 ]; then
  echo "✅ Successfully attached KMS policy to user $USER_NAME"
  echo "Policy name: $POLICY_NAME"
  echo "Please wait 15 seconds for permissions to propagate..."
  sleep 15
else
  echo "❌ Failed to attach policy to user $USER_NAME"
fi

# Clean up
rm /tmp/kms_policy.json

echo "Done."