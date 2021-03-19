#!/bin/bash

LOG_FILE="packer-output.log"

[  -f "${LOG_FILE}" ] || { echo "'${LOG_FILE}' is either empty or does not exist, not updating the AMI's Terraform variables" && exit 1; }

AMI_NAME=${BUILD}-ami-${BUILD_NUMBER}
AMI_ID=$(cat packer-output.log | grep us-east-1: | awk '{ FS = ": " ; print $NF}')

echo -e "\nCommit and push new tag:"
echo -e "git commit . -m \"${AMI_ID} ${AMI_NAME}\""
echo -e "git tag -m \"${AMI_ID}\" ${AMI_NAME}"
echo -e "git push origin ${AMI_NAME}"
