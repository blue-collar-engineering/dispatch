#!/bin/sh

# Create VPC with simpler command substitution
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "10.0.0.0/16" \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=SimpleAppVPC}]' \
  --query 'Vpc.VpcId' \
  --output text)

# Create Subnet
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "10.0.1.0/24" \
  --query 'Subnet.SubnetId' \
  --output text)

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

# Attach gateway - note the quoting
aws ec2 attach-internet-gateway \
  --vpc-id "$VPC_ID" \
  --internet-gateway-id "$IGW_ID"

# Create Route Table
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Create route - note the careful quoting
aws ec2 create-route \
  --route-table-id "$ROUTE_TABLE_ID" \
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id "$IGW_ID"

aws ec2 associate-route-table \
  --subnet-id "$SUBNET_ID" \
  --route-table-id "$ROUTE_TABLE_ID"

# Export variables (using simple echo instead of here-doc)
echo "VPC_ID=$VPC_ID"
echo "SUBNET_ID=$SUBNET_ID"
