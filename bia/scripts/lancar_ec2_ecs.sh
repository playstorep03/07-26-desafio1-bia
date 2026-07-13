#!/bin/bash

# AMI ECS-optimized (Amazon Linux 2023) - Free tier: t2.micro
CLUSTER_NAME="cluster-bia"
INSTANCE_TYPE="t3.micro"
AMI_ID="ami-0f00ab2270b3813ee"

vpc_id=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query "Vpcs[0].VpcId" --output text)
subnet_id=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpc_id Name=availabilityZone,Values=us-east-1a --query "Subnets[0].SubnetId" --output text)
security_group_id=$(aws ec2 describe-security-groups --group-names "bia-dev" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ -z "$security_group_id" ]; then
    echo "[ERRO] Security group bia-dev não encontrado na VPC $vpc_id"
    exit 1
fi

# User data: registra a instância no cluster ECS
USER_DATA=$(cat <<EOF
#!/bin/bash
echo ECS_CLUSTER=$CLUSTER_NAME >> /etc/ecs/ecs.config
EOF
)

aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --security-group-ids $security_group_id \
  --subnet-id $subnet_id \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30,"VolumeType":"gp2"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bia-ecs-node}]' \
  --iam-instance-profile Name=role-acesso-ssm \
  --user-data "$USER_DATA"

echo "Instância EC2 lançada e registrando no cluster $CLUSTER_NAME..."
