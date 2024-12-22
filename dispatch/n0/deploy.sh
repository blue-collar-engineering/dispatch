#!/bin/sh
# Usage: ./deploy.sh app-name docker-image

# Argument checking
if [ $# -ne 2 ]; then
  echo "Usage: $0 app-name docker-image"
  exit 1
fi

APP_NAME=$1
DOCKER_IMAGE=$2

# Set error handling
set -e
trap 'echo "Error on line $LINENO"' ERR

# Load environment variables if they exist
if [ -f .env ]; then
  . .env
fi

echo "Starting deployment for $APP_NAME using image $DOCKER_IMAGE"

# Run network setup
echo "Setting up network..."
. ./setup-network.sh

# Run security setup
echo "Configuring security..."
. ./setup-security.sh

# Deploy application
echo "Deploying application..."
. ./deploy-app.sh

# Save environment variables
# Convert space-separated subnet IDs to comma-separated for .env storage
SUBNET_IDS_CSV=$(echo "$SUBNET_IDS" | tr ' ' ',')

echo "VPC_ID=$VPC_ID" >.env
echo "SUBNET_IDS=$SUBNET_IDS_CSV" >>.env
echo "SECURITY_GROUP_ID=$SG_ID" >>.env
echo "LAUNCH_TEMPLATE_ID=$LAUNCH_TEMPLATE_ID" >>.env
echo "ALB_ARN=$ALB_ARN" >>.env
echo "TG_ARN=$TG_ARN" >>.env
echo "SG_ID=$SG_ID" >>.env
echo "ROUTE_TABLE_ID=$ROUTE_TABLE_ID" >>.env
echo "IGW_ID=$IGW_ID" >>.env

echo "Deployment complete!"
echo "Load balancer DNS name:"
aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].DNSName' \
  --output text
