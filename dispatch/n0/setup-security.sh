#!/bin/sh

# Input validation
if [ -z "$VPC_ID" ]; then
  echo "Error: VPC_ID is required"
  exit 1
fi

# Create Security Group
SG_ID=$(aws ec2 create-security-group \
  --group-name "SimpleAppSG" \
  --description "Security group for simple app deployment" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' \
  --output text)

# Allow inbound HTTP traffic
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr "0.0.0.0/0"

# Allow SSH access (optional)
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "0.0.0.0/0"

# Output the security group ID
echo "SECURITY_GROUP_ID=$SG_ID"
