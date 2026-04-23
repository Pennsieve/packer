#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/test.env"

# Load config from .env file
if [ -f "$ENV_FILE" ]; then
    echo "==> Loading config from $ENV_FILE"
    source "$ENV_FILE"
else
    echo "ERROR: $ENV_FILE not found"
    echo "Create one with the following variables:"
    cat <<EOF
INSTANCE_TYPE="t3.small"
KEY_NAME="your-key-name"
KEY_PATH="~/.ssh/your-key.pem"
SECURITY_GROUP="sg-xxxxxxxx"
SUBNET_ID="subnet-xxxxxxxx"
SSH_USER="ubuntu"
EOF
    exit 1
fi

# Build scripts to test (in order)
SCRIPTS=(
    "scripts/install_puppet.sh"
    "scripts/jenkins.sh"
)

# Read the template file to get the source AMI filters
TEMPLATE_FILE="${SCRIPT_DIR}/templates/jenkins.json"
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "ERROR: $TEMPLATE_FILE not found"
    exit 1
fi

AMI_NAME_FILTER=$(jq -r '.builders[0].source_ami_filter.filters.name' "$TEMPLATE_FILE")
AMI_OWNER=$(jq -r '.builders[0].source_ami_filter.owners[0]' "$TEMPLATE_FILE")
AMI_VIRT_TYPE=$(jq -r '.builders[0].source_ami_filter.filters["virtualization-type"]' "$TEMPLATE_FILE")
AMI_ROOT_TYPE=$(jq -r '.builders[0].source_ami_filter.filters["root-device-type"]' "$TEMPLATE_FILE")

# Parse args
KEEP_RUNNING=false
LOG_FILE="${SCRIPT_DIR}/test-output.log"

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep) KEEP_RUNNING=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1
echo "==> Log started at $(date)"
echo "==> Writing to $LOG_FILE"

# Find AMI using filters from jenkins.json
echo "==> Finding latest AMI..."

AMI_ID=$(aws ec2 describe-images \
    --owners "$AMI_OWNER" \
    --filters \
        "Name=name,Values=$AMI_NAME_FILTER" \
        "Name=virtualization-type,Values=$AMI_VIRT_TYPE" \
        "Name=root-device-type,Values=$AMI_ROOT_TYPE" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text)

if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
    echo "ERROR: Could not find matching AMI"
    exit 1
fi

echo "    Using AMI: $AMI_ID"

echo "==> Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP" \
    --subnet-id "$SUBNET_ID" \
    --no-associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=packer-test-$(date +%s)}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "    Instance ID: $INSTANCE_ID"

cleanup() {
    if [[ "$KEEP_RUNNING" == "false" ]]; then
        echo "==> Terminating instance..."
        aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" > /dev/null
    else
        echo "==> Instance left running: $INSTANCE_ID"
        echo "    Terminate manually: aws ec2 terminate-instances --instance-ids $INSTANCE_ID"
    fi
}
trap cleanup EXIT

echo "==> Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

echo "    Private IP: $INSTANCE_IP"

echo "==> Waiting for SSH to be ready..."
for i in {1..30}; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$KEY_PATH" "$SSH_USER@$INSTANCE_IP" true 2>/dev/null; then
        break
    fi
    echo "    Attempt $i/30..."
    sleep 10
done

echo "==> Copying scripts..."
scp -o StrictHostKeyChecking=no -i "$KEY_PATH" -r scripts "$SSH_USER@$INSTANCE_IP":~/

echo "==> Running provisioning scripts..."
for script in "${SCRIPTS[@]}"; do
    script_name=$(basename "$script")
    echo "--- Running $script_name ---"
    ## sudo -E is used to match provisioners.execute_command in jenkins.json and ecs.json. This means that HOME is set to
    ## the home dir of the ssh-ing user, in this case ubuntu, even though the script is running as root. As verified by both install_puppet.sh and jenkins.sh
    ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "$SSH_USER@$INSTANCE_IP" \
        "sudo -E bash ~/scripts/$script_name"
done

echo "==> All scripts completed successfully!"

if [[ "$KEEP_RUNNING" == "true" ]]; then
    echo "==> SSH in with: ssh -i $KEY_PATH $SSH_USER@$INSTANCE_IP"
fi
