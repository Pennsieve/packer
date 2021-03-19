#!/bin/bash -e
# This script uses Packer to build new AMIs.

BUILD_TYPE="${1}"
BUILD_NUMBER="4"
LOG_FILE="packer-output.log"
VALID_BUILD_TYPES="^(base|developers|docker|jenkins|tomcat)"
BUILD_TYPE="eb-tomcat"

### Packer Variables
ACCCOUNTS_TO_SHARE_AMI=""
AMI_REGIONS="us-east-1"
SECURITY_GROUP_ID="sg-9e132ded"
#SOURCE_AMI="ami-6edd3078"
SSH_USERNAME="ec2-user"
SUBNET_ID="subnet-daeb2791"
VPC_ID="vpc-e7d3259f"

run_packer() {
  packer build -color=false \
               -var "BUILD_NUMBER=${BUILD_NUMBER}" \
               -var "BUILD_TYPE=${BUILD_TYPE}" \
               -var "SECURITY_GROUP_ID=${SECURITY_GROUP_ID}" \
               -var "SOURCE_AMI=${SOURCE_AMI}" \
               -var "SSH_USERNAME=${SSH_USERNAME}" \
               -var "SUBNET_ID=${SUBNET_ID}" \
               -var "VPC_ID=${VPC_ID}" \
               ami.json | tee ${LOG_FILE}
}

cleanup_puppet_master() {
  #INSTANCE_ID=$(grep Instance\ ID packer-output.log | awk '{print $NF}')
  #PUBLIC_DNS_NAME=$(aws --output text ec2 describe-instances --instance-ids ${INSTANCE_ID} --query Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[*].PrivateDnsName)
  PUBLIC_DNS_NAME=$(grep Creating\ a\ new\ SSL\ key packer-output.log | awk '{print $9}' | sed -e 's/\033\[0m\015//')
  
  echo "Instance ID is $INSTANCE_ID"

  echo "ssh -t ops-pup-master-use1.blackfynn.io \"sudo /opt/puppetlabs/bin/puppet cert clean $PUBLIC_DNS_NAME\""
  #if [ -z $PUBLIC_DNS_NAME ] ; then
  #  echo "Not cleaning Puppet Server"
  #  exit 2
  #else
  #  echo "Cleaning Puppet cert for $PUBLIC_DNS_NAME"
  #  echo "ssh -t ops-pup-master-use1.blackfynn.io \"sudo /opt/puppetlabs/bin/puppet cert clean $PUBLIC_DNS_NAME\""
  #fi
}

git_tag() {
  [  -f "${LOG_FILE}" ] || { echo "'${LOG_FILE}' is either empty or does not exist, not updating the AMI's Terraform variables" && exit 1; }

  AMI_NAME=${BUILD_TYPE}-ami-${BUILD_NUMBER}
  AMI_ID=$(cat packer-output.log | grep us-east-1: | awk '{ FS = ": " ; print $NF}')
  echo -e "\nCommit and push new tag:"
  echo -e "git commit . -m \"${AMI_ID} ${AMI_NAME}\""
  echo -e "git tag -m \"${AMI_ID}\" ${AMI_NAME}"
  echo -e "git push origin ${AMI_NAME}"
}

run_packer
cleanup_puppet_master
