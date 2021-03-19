#!/bin/bash
# This script uses Packer to build new AMIs.

BUILD_TYPE="${1}"
BUILD_NUMBER="35"
LOG_FILE="packer-output.log"
VALID_BUILD_TYPES="^(base|developers|docker|jenkins|tomcat)"
BUILD_TYPE="jenkins"

### Packer Variables
PACKER_LOG=0
ACCCOUNTS_TO_SHARE_AMI=""
AMI_REGIONS="us-east-1"
SECURITY_GROUP_ID="sg-9e132ded"
#SOURCE_AMI="ami-6edd3078"
SSH_USERNAME="ubuntu"
SUBNET_ID="subnet-daeb2791"
VPC_ID="vpc-e7d3259f"


               #-debug \
run_packer() {
  set -e
  packer build -color=false \
               -var "VPC_ID=${VPC_ID}" \
               -var "BUILD_NUMBER=${BUILD_NUMBER}" \
               -var "BUILD_TYPE=${BUILD_TYPE}" \
               -var "SECURITY_GROUP_ID=${SECURITY_GROUP_ID}" \
               -var "SOURCE_AMI=${SOURCE_AMI}" \
               -var "SSH_USERNAME=${SSH_USERNAME}" \
               -var "SUBNET_ID=${SUBNET_ID}" \
               -var "VPC_ID=${VPC_ID}" \
               -var-file=secrets.json \
               ami.json | tee ${LOG_FILE}
  set +e
}

cleanup_puppet_master() {
  INSTANCE_ID=$(grep Instance\ ID packer-output.log | awk '{print $NF}')
  PUBLIC_DNS_NAME=$(aws --output text ec2 describe-instances --instance-ids ${INSTANCE_ID} --query Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].PrivateDnsName)

  if [ -z $PUBLIC_DNS_NAME ] ; then
    echo "Not cleaning Puppet Server"
    exit 2
  else
    echo "Cleaning Puppet cert for $PUBLIC_DNS_NAME"
    ssh -t ops-pup-master-use1.blackfynn.io "sudo /opt/puppetlabs/bin/puppet cert clean $PUBLIC_DNS_NAME"
  fi
}

git_tag() {
  [  -f "${LOG_FILE}" ] || { echo "'${LOG_FILE}' is either empty or does not exist, not updating the AMI's Terraform variables" && exit 1; }

  AMI_NAME=${BUILD_TYPE}-ami-${BUILD_NUMBER}
  AMI_ID=$(cat packer-output.log | grep us-east-1: | awk '{ FS = ": " ; print $NF}')
  SNAPSHOT_ID=$(aws ec2 describe-images --image-ids $AMI_ID --output text --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId')
  echo -e "\nCommit and push new tag:"
  echo -e "git commit . -m \"${AMI_ID} ${SNAPSHOT_ID} ${AMI_NAME}\""
  echo -e "git tag -m \"${AMI_ID} ${SNAPSHOT_ID}\" ${AMI_NAME}"
  echo -e "git push origin ${AMI_NAME}"
  echo -e "\nUpdate the \"Block device mapping\" in the Jenkins Configuration:\n/dev/sda1=$SNAPSHOT_ID:200:true:io1:2250"
}

run_packer
#cleanup_puppet_master
git_tag
