#!/bin/sh
# cleanup.sh

# Load environment variables if they exist
if [ -f .env ]; then
  . .env
fi

# Input validation
if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ] || [ -z "$IGW_ID" ] ||
  [ -z "$ROUTE_TABLE_ID" ] || [ -z "$SG_ID" ] || [ -z "$LAUNCH_TEMPLATE_ID" ] ||
  [ -z "$ALB_ARN" ] || [ -z "$TG_ARN" ]; then
  echo "Error: Required environment variables not set"
  exit 1
fi

# Helper function for error handling
cleanup_error() {
  echo "Error during cleanup: $1"
  exit 1
}

# Delete Auto Scaling Group
echo "Deleting Auto Scaling Group..."
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name "SimpleAppASG" \
  --force-delete || cleanup_error "Failed to delete Auto Scaling Group"

# Wait for ASG to be deleted
echo "Waiting for Auto Scaling Group to be deleted..."
while true; do
  ASG_CHECK=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "SimpleAppASG" \
    --query 'AutoScalingGroups[*]' \
    --output text)
  if [ -z "$ASG_CHECK" ]; then
    echo "Auto Scaling Group deleted"
    break
  fi
  echo "Waiting..."
  sleep 5
done

# Delete Launch Template
echo "Deleting Launch Template..."
aws ec2 delete-launch-template \
  --launch-template-id "$LAUNCH_TEMPLATE_ID" || cleanup_error "Failed to delete Launch Template"

# Delete Listener (before Load Balancer)
echo "Getting and deleting Listener..."
LISTENER_ARN=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$ALB_ARN" \
  --query 'Listeners[0].ListenerArn' \
  --output text)
if [ ! -z "$LISTENER_ARN" ] && [ "$LISTENER_ARN" != "None" ]; then
  aws elbv2 delete-listener \
    --listener-arn "$LISTENER_ARN" || cleanup_error "Failed to delete Listener"
fi

# Delete Load Balancer
echo "Deleting Load Balancer..."
aws elbv2 delete-load-balancer \
  --load-balancer-arn "$ALB_ARN" || cleanup_error "Failed to delete Load Balancer"

# Wait for Load Balancer to be deleted
echo "Waiting for Load Balancer to be deleted..."
while true; do
  LB_CHECK=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query 'LoadBalancers[*]' \
    --output text 2>/dev/null || echo "")
  if [ -z "$LB_CHECK" ]; then
    echo "Load Balancer deleted"
    break
  fi
  echo "Waiting..."
  sleep 5
done

# Delete Target Group
echo "Deleting Target Group..."
aws elbv2 delete-target-group \
  --target-group-arn "$TG_ARN" || cleanup_error "Failed to delete Target Group"

# Delete Security Group
sleep 15 # wait for instances,etc to all disassociate
echo "Deleting Security Group..."
aws ec2 delete-security-group \
  --group-id "$SG_ID" || cleanup_error "Failed to delete Security Group"

# Get and delete non-main route table associations
echo "Removing route table associations..."
ASSOC_IDS=$(aws ec2 describe-route-tables \
  --route-table-id "$ROUTE_TABLE_ID" \
  --query 'RouteTables[].Associations[?!Main].RouteTableAssociationId' \
  --output text)

if [ ! -z "$ASSOC_IDS" ]; then
  for ASSOC_ID in $ASSOC_IDS; do
    echo "Deleting route table association $ASSOC_ID"
    aws ec2 disassociate-route-table --association-id "$ASSOC_ID" ||
      cleanup_error "Failed to disassociate route table"
  done
fi

# Delete routes in the route table
echo "Deleting routes from route table..."
aws ec2 describe-route-tables \
  --route-table-id "$ROUTE_TABLE_ID" \
  --query 'RouteTables[].Routes[?GatewayId != `local`].DestinationCidrBlock' \
  --output text | while read -r cidr; do
  if [ ! -z "$cidr" ]; then
    echo "Deleting route for $cidr"
    aws ec2 delete-route \
      --route-table-id "$ROUTE_TABLE_ID" \
      --destination-cidr-block "$cidr" ||
      cleanup_error "Failed to delete route for $cidr"
  fi
done

# Delete Route Table
echo "Deleting Route Table..."
aws ec2 delete-route-table \
  --route-table-id "$ROUTE_TABLE_ID" || cleanup_error "Failed to delete Route Table"

# Detach and Delete Internet Gateway
echo "Detaching Internet Gateway..."
aws ec2 detach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID" || cleanup_error "Failed to detach Internet Gateway"

echo "Deleting Internet Gateway..."
aws ec2 delete-internet-gateway \
  --internet-gateway-id "$IGW_ID" || cleanup_error "Failed to delete Internet Gateway"

# Delete Subnets
echo "Deleting Subnets..."
OLD_IFS=$IFS
IFS=','
for SUBNET_ID in $SUBNET_IDS; do
  echo "Deleting subnet $SUBNET_ID"
  aws ec2 delete-subnet \
    --subnet-id "$SUBNET_ID" || cleanup_error "Failed to delete Subnet $SUBNET_ID"
done
IFS=$OLD_IFS

# Delete VPC
echo "Deleting VPC..."
aws ec2 delete-vpc \
  --vpc-id "$VPC_ID" || cleanup_error "Failed to delete VPC"

# Remove environment file
rm -f .env

echo "Cleanup completed successfully!"
