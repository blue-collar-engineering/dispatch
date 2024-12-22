#!/bin/sh

# Input validation
if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ] || [ -z "$SG_ID" ]; then
  echo "Error: Required environment variables not set"
  echo "Required: VPC_ID, SUBNET_IDS, SG_ID"
  exit 1
fi

if [ -z "$DOCKER_IMAGE" ]; then
  echo "Error: DOCKER_IMAGE environment variable not set"
  exit 1
fi

# Create the service-linked role for Auto Scaling if it doesn't exist
echo "Ensuring Auto Scaling service-linked role exists..."
aws iam create-service-linked-role --aws-service-name autoscaling.amazonaws.com 2>/dev/null || true
# Wait a moment for role propagation
sleep 10

# Create user data script
USER_DATA=$(printf '#!/bin/sh\napt update\napt install -y docker.io\nsystemctl start docker\ndocker pull %s\ndocker run -d -p 80:80 %s' "$DOCKER_IMAGE" "$DOCKER_IMAGE" | base64)

# Create Launch Template
echo "Creating Launch Template..."
LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
  --launch-template-name "SimpleAppTemplate" \
  --version-description "Initial version" \
  --launch-template-data "{
        \"ImageId\": \"ami-0d4eea77bb23270f4\",
        \"InstanceType\": \"t4g.micro\",
        \"SecurityGroupIds\": [\"$SG_ID\"],
        \"UserData\": \"$USER_DATA\"
    }" \
  --query 'LaunchTemplate.LaunchTemplateId' \
  --output text)

# Format subnet IDs for AWS CLI
SUBNET_LIST=$(echo "$SUBNET_IDS" | tr ' ' ',')

# Create Load Balancer
echo "Creating Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name "SimpleAppALB" \
  --subnets $SUBNET_IDS \
  --security-groups "$SG_ID" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Wait for Load Balancer to be active
echo "Waiting for Load Balancer to be active..."
while true; do
  STATUS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query 'LoadBalancers[0].State.Code' \
    --output text)
  if [ "$STATUS" = "active" ]; then
    break
  fi
  echo "Load Balancer status: $STATUS"
  sleep 10
done

# Create Target Group
echo "Creating Target Group..."
TG_ARN=$(aws elbv2 create-target-group \
  --name "SimpleAppTG" \
  --protocol "HTTP" \
  --port 80 \
  --vpc-id "$VPC_ID" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Create Listener
echo "Creating Listener..."
aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --protocol "HTTP" \
  --port 80 \
  --default-actions "Type=forward,TargetGroupArn=$TG_ARN"

# Create Auto Scaling Group with multiple subnets
echo "Creating Auto Scaling Group..."
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name "SimpleAppASG" \
  --launch-template "LaunchTemplateId=$LAUNCH_TEMPLATE_ID" \
  --min-size 1 \
  --max-size 3 \
  --desired-capacity 2 \
  --vpc-zone-identifier "$SUBNET_LIST" \
  --target-group-arns "$TG_ARN" \
  --health-check-type "ELB" \
  --health-check-grace-period 300

# Add Scaling Policy
echo "Creating Scaling Policy..."
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name "SimpleAppASG" \
  --policy-name "CPUScaling" \
  --policy-type "TargetTrackingScaling" \
  --target-tracking-configuration '{
        "TargetValue": 75.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ASGAverageCPUUtilization"
        }
    }'

# Export variables
echo "LAUNCH_TEMPLATE_ID=$LAUNCH_TEMPLATE_ID"
echo "ALB_ARN=$ALB_ARN"
echo "TG_ARN=$TG_ARN"

echo "Deployment complete! Load Balancer DNS name:"
aws elbv2 describe-load-balancers \
  --load-balancer-arns "$ALB_ARN" \
  --query 'LoadBalancers[0].DNSName' \
  --output text
