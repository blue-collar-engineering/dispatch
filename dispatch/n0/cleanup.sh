#!/bin/sh

# Load environment variables if they exist
if [ -f .env ]; then
  . .env
fi

# Input validation
if [ -z "$VPC_ID" ] || [ -z "$SUBNET_ID" ] || [ -z "$IGW_ID" ] ||
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
while aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "SimpleAppASG" \
  --query 'AutoScalingGroups[0]' \
  --output text >/dev/null 2>&1; do
  sleep 5
done

# Delete Launch Template
echo "Deleting Launch Template..."
aws ec2 delete-launch-template \
  --launch-template-id "$LAUNCH_TEMPLATE_ID" || cleanup_error "Failed to delete Launch Template"

# Delete Load Balancer
echo "Deleting Load Balancer..."
aws elbv2 delete-load-balancer \
  --load-balancer-arn "$ALB_ARN" || cleanup_error "Failed to delete Load Balancer"

# Wait for Load Balancer to be deleted
echo "Waiting for Load Balancer to be deleted..."
while aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0]' \
  --output text >/dev/null 2>&1; do
  sleep 5
done

# Delete Target Group
echo "Deleting Target Group..."
aws elbv2 delete-target-group \
  --target-group-arn "$TG_ARN" || cleanup_error "Failed to delete Target Group"

# Delete Security Group
echo "Deleting Security Group..."
aws ec2 delete-security-group \
  --group-id "$SG_ID" || cleanup_error "Failed to delete Security Group"

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

# Delete Subnet
echo "Deleting Subnet..."
aws ec2 delete-subnet \
  --subnet-id "$SUBNET_ID" || cleanup_error "Failed to delete Subnet"

# Delete VPC
echo "Deleting VPC..."
aws ec2 delete-vpc \
  --vpc-id "$VPC_ID" || cleanup_error "Failed to delete VPC"

# Remove environment file
rm -f .env

echo "Cleanup completed successfully!"
