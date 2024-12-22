# Simple AWS Deployment Guide

This repository contains POSIX-compliant shell scripts for deploying applications on AWS without Kubernetes. It accompanies the Blue-Collar Engineering newsletter article "You Don't Need Kubernetes (Yet)".

## Features

- ✅ POSIX shell compatible (works with sh, bash, dash, etc.)
- ✅ Automatic VPC and networking setup
- ✅ Load balancing with Auto Scaling Groups
- ✅ Simple deployment and cleanup
- ✅ Comprehensive error handling
- ✅ No Kubernetes required

## Prerequisites

Before you begin, ensure you have:

1. AWS CLI v2 installed and configured with appropriate credentials

   ```sh
   aws --version  # Should be 2.x.x or higher
   ```

2. Docker installed locally (or compatible container runtime)

   ```sh
   docker --version
   ```

3. A Docker image of your application pushed to a registry

4. AWS IAM permissions for:
   - EC2 (instances, security groups, VPC)
   - Auto Scaling Groups
   - Elastic Load Balancing
   - CloudWatch (for monitoring)

## Quick Start

1. Clone this repository:

   ```sh
   git clone https://github.com/blue-collar-engineering/dispatch.git
   cd dispatch/n0
   ```

2. Make scripts executable:

   ```sh
   chmod +x *.sh
   ```

3. Deploy your application:

   ```sh
   ./deploy.sh your-app-name your-docker-image
   ```

This will create:

- A VPC with proper networking
- An Auto Scaling Group with 1-3 instances
- A load balancer
- CloudWatch monitoring

## Script Details

### deploy.sh

Main deployment script that orchestrates the entire setup:

```sh
./deploy.sh app-name docker-image:tag
```

### setup-network.sh

Creates VPC, subnet, internet gateway, and routing:

```sh
. ./setup-network.sh
```

### setup-security.sh

Sets up security groups with proper ingress rules:

```sh
. ./setup-security.sh
```

### deploy-app.sh

Deploys your application with auto-scaling:

```sh
. ./deploy-app.sh
```

### cleanup.sh

Removes all created resources:

```sh
./cleanup.sh
```

## Environment Variables

The scripts create a `.env` file containing:

- VPC_ID
- SUBNET_ID
- SECURITY_GROUP_ID
- LAUNCH_TEMPLATE_ID
- ALB_ARN
- TG_ARN

This file is used for cleanup and reference.

## Monitoring

Monitor your deployment using AWS CloudWatch:

1. CPU Utilization:

   ```sh
   aws cloudwatch get-metric-statistics \
       --namespace AWS/EC2 \
       --metric-name CPUUtilization \
       --dimensions Name=AutoScalingGroupName,Value=SimpleAppASG \
       --start-time "$(date -u -v-1H '+%Y-%m-%dT%H:%M:%S')" \
       --end-time "$(date -u '+%Y-%m-%dT%H:%M:%S')" \
       --period 300 \
       --statistics Average
   ```

2. Load Balancer Metrics:

Get short name from ALB ARN (e.g., app/SimpleAppALB/1234567890)

```sh
ALB_NAME=$(echo "$ALB_ARN" | cut -d'/' -f2,3,4)
```

For Linux (GNU date)

```sh
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value="$ALB_NAME" \
    --start-time "$(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%S')" \
    --end-time "$(date -u '+%Y-%m-%dT%H:%M:%S')" \
    --period 300 \
    --statistics Sum
```

For MacOS (BSD date)

```sh
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --dimensions Name=LoadBalancer,Value="$ALB_NAME" \
    --start-time "$(date -u -v-1H '+%Y-%m-%dT%H:%M:%S')" \
    --end-time "$(date -u '+%Y-%m-%dT%H:%M:%S')" \
    --period 300 \
    --statistics Sum
```

## Troubleshooting

### Common Issues

1. **Instance Not Launching**
   - Check security group rules
   - Verify IAM permissions
   - Examine instance logs:

     ```sh
     aws ec2 get-console-output --instance-id <id>
     ```

2. **Auto Scaling Not Working**
   - Verify target group health checks
   - Check scaling policy configuration
   - Monitor CloudWatch alarms

3. **Deployment Failures**
   - Ensure your Docker image is accessible
   - Check VPC/subnet configuration
   - Verify security group rules

### Debugging Tips

1. Check deployment status:

   ```sh
   aws autoscaling describe-auto-scaling-groups \
       --auto-scaling-group-names SimpleAppASG
   ```

2. View load balancer health:

   ```sh
   aws elbv2 describe-target-health \
       --target-group-arn "$TG_ARN"
   ```

3. Access instance logs:

   ```sh
   aws ec2 get-console-output --instance-id <id>
   ```

## Security Considerations

1. The default security group allows inbound HTTP (80) and SSH (22)
2. Modify `setup-security.sh` to restrict access as needed
3. Consider adding HTTPS support for production use
4. Review IAM permissions regularly

## Scaling

The default configuration:

- Minimum: 1 instance
- Maximum: 3 instances
- Scales based on 75% CPU utilization

Modify these in `deploy-app.sh` according to your needs.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

Follow POSIX shell guidelines when contributing.

## License

MIT License - See LICENSE file for details.

## Support

- Create an issue in this repository
- Reference the newsletter: [Blue-Collar Engineering](https://your-newsletter-url.com)

## Acknowledgments

This project is part of the Blue-Collar Engineering series, promoting practical, no-nonsense approaches to system engineering.
