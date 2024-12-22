#!/bin/sh

# Create VPC
echo "Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "10.0.0.0/16" \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=SimpleAppVPC}]' \
  --query 'Vpc.VpcId' \
  --output text)

# Get first two availability zones in the region
echo "Getting availability zones..."
AZS=$(aws ec2 describe-availability-zones \
  --query 'AvailabilityZones[0:2].ZoneId' \
  --output text)

# Create subnets in different AZs
echo "Creating subnets..."
SUBNET_IDS=""
CIDR_BLOCK_COUNTER=0

for AZ in $AZS; do
  SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "10.0.$CIDR_BLOCK_COUNTER.0/24" \
    --availability-zone-id "$AZ" \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=SimpleAppSubnet-$AZ}]" \
    --query 'Subnet.SubnetId' \
    --output text)

  # Enable auto-assign public IP
  aws ec2 modify-subnet-attribute \
    --subnet-id "$SUBNET_ID" \
    --map-public-ip-on-launch

  if [ -z "$SUBNET_IDS" ]; then
    SUBNET_IDS="$SUBNET_ID"
  else
    SUBNET_IDS="$SUBNET_IDS $SUBNET_ID"
  fi

  CIDR_BLOCK_COUNTER=$((CIDR_BLOCK_COUNTER + 1))
done

# Create Internet Gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

# Attach gateway
aws ec2 attach-internet-gateway \
  --vpc-id "$VPC_ID" \
  --internet-gateway-id "$IGW_ID"

# Create Route Table
echo "Creating Route Table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Create route
aws ec2 create-route \
  --route-table-id "$ROUTE_TABLE_ID" \
  --destination-cidr-block "0.0.0.0/0" \
  --gateway-id "$IGW_ID"

# Associate route table with all subnets
echo "Associating Route Table with subnets..."
for SUBNET_ID in $SUBNET_IDS; do
  aws ec2 associate-route-table \
    --subnet-id "$SUBNET_ID" \
    --route-table-id "$ROUTE_TABLE_ID"
done

# Export variables
echo "VPC_ID=$VPC_ID"
echo "SUBNET_IDS=$SUBNET_IDS"
