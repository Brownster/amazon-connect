#!/bin/bash
# Script to manually clean up AWS resources if terraform destroy fails
# This script requires AWS CLI v2 with the appropriate credentials configured

echo "WARNING: This script will delete resources created by the Terraform configuration."
echo "Make sure you have the appropriate credentials set up."
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="eu-west-2" # Change this if you're using a different region
CONNECT_INSTANCE_ID=$(terraform output -raw connect_instance_id 2>/dev/null || echo "")
CONNECT_CTR_STREAM=$(terraform output -raw kinesis_stream_name 2>/dev/null || echo "connect-ctr-stream")
S3_DATA_BUCKET=$(terraform output -raw s3_data_bucket 2>/dev/null || echo "")
ATHENA_RESULTS_BUCKET=$(aws s3 ls | grep "connect-analytics-athena-results-" | awk '{print $3}')
DATABASE_NAME=$(terraform output -raw athena_database 2>/dev/null || echo "connect_ctr_database")
INSTANCE_ID=$(terraform output -raw grafana_public_ip 2>/dev/null | aws ec2 describe-instances --filters "Name=public-ip-address,Values=$ip" --query "Reservations[0].Instances[0].InstanceId" --output text 2>/dev/null || echo "")

echo "Using the following values:"
echo "- Account ID: $ACCOUNT_ID"
echo "- Region: $REGION"
echo "- Connect Instance ID: $CONNECT_INSTANCE_ID"
echo "- Kinesis Stream: $CONNECT_CTR_STREAM"
echo "- S3 Data Bucket: $S3_DATA_BUCKET"
echo "- Athena Results Bucket: $ATHENA_RESULTS_BUCKET"
echo "- Database Name: $DATABASE_NAME"
echo "- EC2 Instance ID: $INSTANCE_ID"

# Function to run a command and handle errors
run_command() {
    echo "Running: $1"
    eval "$1"
    if [ $? -ne 0 ]; then
        echo "Warning: Command failed, continuing..."
    fi
}

echo "Step 1: Emptying S3 buckets (required before deletion)"
if [ ! -z "$S3_DATA_BUCKET" ]; then
    run_command "aws s3 rm s3://$S3_DATA_BUCKET --recursive"
fi
if [ ! -z "$ATHENA_RESULTS_BUCKET" ]; then
    run_command "aws s3 rm s3://$ATHENA_RESULTS_BUCKET --recursive"
fi

echo "Step 2: Deleting Firehose delivery stream"
run_command "aws firehose delete-delivery-stream --delivery-stream-name connect-ctr-delivery-stream"

echo "Step 3: Deleting Kinesis stream"
run_command "aws kinesis delete-stream --stream-name $CONNECT_CTR_STREAM"

echo "Step 4: Deleting Glue database (this will also delete tables)"
# First, let's get all tables and delete them
tables=$(aws glue get-tables --database-name $DATABASE_NAME --query "TableList[].Name" --output text 2>/dev/null)
for table in $tables; do
    run_command "aws glue delete-table --database-name $DATABASE_NAME --name $table"
done

# Now try to delete the database
run_command "aws glue delete-database --name $DATABASE_NAME"

echo "Step 5: Deleting Glue crawler"
run_command "aws glue delete-crawler --name connect-ctr-crawler"

echo "Step 6: Deleting Athena workgroup"
run_command "aws athena delete-work-group --work-group connect-analytics --recursive-delete-option"

echo "Step 7: Terminating EC2 instance"
if [ ! -z "$INSTANCE_ID" ]; then
    run_command "aws ec2 terminate-instances --instance-ids $INSTANCE_ID"
fi

echo "Step 8: Deleting Connect Instance"
if [ ! -z "$CONNECT_INSTANCE_ID" ]; then
    run_command "aws connect delete-instance --instance-id $CONNECT_INSTANCE_ID"
fi

echo "Step 9: Deleting IAM roles and policies"
# First, remove roles from instance profiles
run_command "aws iam remove-role-from-instance-profile --instance-profile-name grafana-instance-profile --role-name grafana-instance-role"

# Then, detach policies from roles
for role in "connect-kinesis-role" "glue-crawler-role" "firehose-role" "grafana-instance-role"; do
    # Get all attached policies
    policies=$(aws iam list-attached-role-policies --role-name $role --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null)
    for policy in $policies; do
        run_command "aws iam detach-role-policy --role-name $role --policy-arn $policy"
    done
    
    # Get all inline policies
    inline_policies=$(aws iam list-role-policies --role-name $role --query "PolicyNames" --output text 2>/dev/null)
    for policy in $inline_policies; do
        run_command "aws iam delete-role-policy --role-name $role --policy-name $policy"
    done
    
    # Delete the role
    run_command "aws iam delete-role --role-name $role"
done

# Delete instance profile
run_command "aws iam delete-instance-profile --instance-profile-name grafana-instance-profile"

echo "Step 10: Deleting S3 buckets"
if [ ! -z "$S3_DATA_BUCKET" ]; then
    run_command "aws s3 rb s3://$S3_DATA_BUCKET --force"
fi
if [ ! -z "$ATHENA_RESULTS_BUCKET" ]; then
    run_command "aws s3 rb s3://$ATHENA_RESULTS_BUCKET --force"
fi

echo "Step 11: Deleting network resources"
# Get VPC ID
vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=connect-analytics-vpc" --query "Vpcs[0].VpcId" --output text 2>/dev/null)
if [ ! -z "$vpc_id" ] && [ "$vpc_id" != "None" ]; then
    # Delete security groups
    security_groups=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
    for sg in $security_groups; do
        run_command "aws ec2 delete-security-group --group-id $sg"
    done
    
    # Delete internet gateway
    igw_id=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query "InternetGateways[0].InternetGatewayId" --output text)
    if [ ! -z "$igw_id" ] && [ "$igw_id" != "None" ]; then
        run_command "aws ec2 detach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id"
        run_command "aws ec2 delete-internet-gateway --internet-gateway-id $igw_id"
    fi
    
    # Delete route tables
    route_tables=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text)
    for rt in $route_tables; do
        # First remove associations
        associations=$(aws ec2 describe-route-tables --route-table-ids $rt --query "RouteTables[0].Associations[].RouteTableAssociationId" --output text)
        for assoc in $associations; do
            run_command "aws ec2 disassociate-route-table --association-id $assoc"
        done
        run_command "aws ec2 delete-route-table --route-table-id $rt"
    done
    
    # Delete subnets
    subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[].SubnetId" --output text)
    for subnet in $subnets; do
        run_command "aws ec2 delete-subnet --subnet-id $subnet"
    done
    
    # Delete VPC
    run_command "aws ec2 delete-vpc --vpc-id $vpc_id"
fi

echo "Clean-up operation completed. Some resources may still exist if they have dependencies."
echo "You may need to check the AWS console to verify all resources were deleted successfully."