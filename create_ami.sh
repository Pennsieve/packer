#!/bin/bash -e
# This script uses Packer to build new AMIs.

BUILD_TYPE="${1}"
LOG_FILE="packer-output.log"
TEMPLATE_DIR="templates"
VARIABLES_FILE_NAME="variables.json"

help_message() {
  SUPPORTED_BUILD_TYPES=$(find ./${TEMPLATE_DIR} -d 1 -type f -exec basename {} \; | grep -v variables | awk -F. '{print $1}')
  echo "Usage: $0 <ami_build_type>"
  echo " "
  echo -e "Supported Build Types: \n${SUPPORTED_BUILD_TYPES}"
  exit 1
}

get_ami_name() {
  # Get the last AMI version/build number
  OLD_BUILD_NUMBER=$(aws ec2 describe-images --filters "Name=name,Values=${BUILD_TYPE}-ami-*" "Name=is-public,Values=false" \
                                             --query "sort_by(Images, &CreationDate)[-1].Name" \
                                             --output text | \
                                             awk -F- '{print $3}')

  if [ -z "${OLD_BUILD_NUMBER}" ]; then
    echo "OLD_BUILD_NUMBER not set, is this the first time building this build type?"
    exit 1
  else
    BUILD_NUMBER=$((OLD_BUILD_NUMBER+1))
    AMI_NAME=${BUILD_TYPE}-ami-${BUILD_NUMBER}
  fi

  # # First time building 
  # BUILD_NUMBER=1
  # AMI_NAME=${BUILD_TYPE}-ami-${BUILD_NUMBER}


  echo "AMI_NAME=$AMI_NAME"
}

packer_build() {
  # This setting takes the exit code from the packer command
  # so we don't get false positives from the pipe to tee

  if [ "${BUILD_TYPE}" = jenkins ]; then
    VARIABLES_FILE_NAME="variables.json"
  fi

  set -euo pipefail

  packer build -color=false \
               -var-file=${TEMPLATE_DIR}/${VARIABLES_FILE_NAME} \
               -var "ami_name=${AMI_NAME}" \
               ${TEMPLATE_DIR}/${BUILD_TYPE}.json | tee ${LOG_FILE}
  unset euo
}

generate_git_tag_commands() {
  [  -f "${LOG_FILE}" ] || { echo "'${LOG_FILE}' is either empty or does not exist, not updating the AMI's Terraform variables" && exit 1; }

  AMI_ID=$(awk '/us-east-1: a/ {print $2}' packer-output.log)
  SNAPSHOT_ID=$(aws ec2 describe-images --image-ids $AMI_ID --output text --query 'Images[*].BlockDeviceMappings[*].Ebs.SnapshotId')

  if [ "$BUILD_TYPE" = jenkins ]; then
    echo -e "\nUpdate the \"Block device mapping\" in the Jenkins Configuration:\n/dev/sda1=$SNAPSHOT_ID:750:true:gp2"
  fi

  echo -e "\nCommit and push new tag:"

  if [ "${SNAPSHOT_ID}" = "" ]; then
    echo -e "git commit . -m \"${AMI_ID} ${AMI_NAME}\""
    echo -e "git tag -m \"${AMI_ID}\" ${AMI_NAME}"
  else
    echo -e "git commit . -m \"${AMI_ID} ${SNAPSHOT_ID} ${AMI_NAME}\""
    echo -e "git tag -m \"${AMI_ID} ${SNAPSHOT_ID}\" ${AMI_NAME}"
  fi

  echo -e "git push origin ${AMI_NAME}"
}

#### Begin script #####

if [ "$#" -ne 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  help_message
fi

get_ami_name
packer_build
generate_git_tag_commands
