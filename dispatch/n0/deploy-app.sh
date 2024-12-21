#!/bin/sh

# Input validation
if [ -z "$VPC_ID" ] || [ -z "$SUBNET_ID" ] || [ -z "$SG_ID" ]; then
  echo "Error: Required environment variables not set"
  echo "Required: VPC_ID, SUBNET_ID, SG_ID"
  exit 1
fi

if [ -z "$DOCKER_IMAGE" ]; then
  echo "Error: DOCKER_IMAGE environment variable not set"
  exit 1
fi

# Create user data script - using printf for better portability
USER_DATA=$(printf '#!/bin/sh\napt update\napt install -y docker.io\nsystemctl start docker\ndocker pull %s\ndocker run -d -p 80:80 %s' "$DOCKER_IMAGE" "$DOCKER_IMAGE" | base64)

# Create Launch Template
LAUNCH_TEMPLATE_ID=$(aws ec2 create-launch-template \
  --launch-template-name "SimpleAppTemplate" \
  --version-description "Initial version" \
  --launch-template-data "{
        \"ImageId\": \"ami-08be03eb8827fb402\",
        \"InstanceType\": \"t2.micro\",
        \"SecurityGroupIds\": [\"$SG_ID\"],
        \"UserData\": \"$USER_DATA\"
    }" \
  --query 'LaunchTemplate.LaunchTemplateId' \
  --output text)

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name "SimpleAppASG" \
  --launch-template "LaunchTemplateId=$LAUNCH_TEMPLATE_ID" \
  --min-size 1 \
  --max-size 3 \
  --desired-capacity 2 \
  --vpc-zone-identifier "$SUBNET_ID" \
  --health-check-type "ELB" \
  --health-check-grace-period 300

# Create Load Balancer
ALB_ARN=$(aws elbv2 create-load-balancer \
  --name "SimpleAppALB" \
  --subnets "$SUBNET_ID" \
  --security-groups "$SG_ID" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Create Target Group
TG_ARN=$(aws elbv2 create-target-group \
  --name "SimpleAppTG" \
  --protocol "HTTP" \
  --port 80 \
  --vpc-id "$VPC_ID" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Create Listener
aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --protocol "HTTP" \
  --port 80 \
  --default-actions "Type=forward,TargetGroupArn=$TG_ARN"

# Add Scaling Policy
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
