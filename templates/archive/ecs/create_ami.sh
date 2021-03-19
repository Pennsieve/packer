#!/bin/bash
# This script uses Packer to build new AMIs.

BUILD_TYPE="${1}"
BUILD_NUMBER="17"
LOG_FILE="packer-output.log"
VALID_BUILD_TYPES="^(base|developers|ecs|docker|jenkins)"

### Packer Variables
ACCCOUNTS_TO_SHARE_AMI=""
AMI_REGIONS="us-east-1"
SECURITY_GROUP_ID="sg-9e132ded"
#SOURCE_AMI="ami-6edd3078"
SSH_USERNAME="ec2-user"
SUBNET_ID="subnet-daeb2791"
VPC_ID="vpc-e7d3259f"

help_message() {
  echo -e "Usage: $0 [base|developers|ecs|docker|jenkins|latest_version]\n"
  echo -e "The following arguments are supported:"
  echo -e "\tbase         \t Create a base AMI."
  echo -e "\tdevelopers   \t Add Dev users, create an AMI that installs Docker and everything in the base AMI."
  echo -e "\tdocker       \t Create an AMI that installs Docker and everything in the base AMI."
  echo -e "\tjenkins      \t Create an AMI that installs utilities like Packer and Terraform in addition to everything in Docker and the base AMI."
  exit 1
}

check_variables() {
  [ ! -z "${BUILD_NUMBER}" ] || { echo "BUILD_NUMBER not set." && exit 1; }
  
  if [[ ! "${BUILD_TYPE}" =~ ${VALID_BUILD_TYPES} ]]; then
    help_message
  fi

}

latest_versions() {
  latest_compose="$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq \'.tag_name\')"
  latest_terraform="$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq \'.tag_name\')"
  latest_moby="$(curl -s https://api.github.com/repos/moby/moby/releases/latest | jq \'.tag_name\')"

  echo "Docker-Compose $latest_compose"
  echo "Terraform $latest_terraform" 
  echo "Moby $latest_moby" 
}

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

update_terraform() {
  [  -f "${LOG_FILE}" ] || { echo "'${LOG_FILE}' is either empty or does not exist, not updating the AMI's Terraform variables" && exit 1; }
  
  for REGION in $AMI_REGIONS; do
    IMAGE_ID=$(cat ${LOG_FILE} | grep ${REGION}: | awk '{ FS = ": " ; print $NF}')
  
    if [ ! -z "${IMAGE_ID}" ]; then
      echo ${IMAGE_ID}
      sed -ri "s/${REGION}.*/${REGION} = \"${IMAGE_ID}\"/g" ./terraform-ami-module/${BUILD_TYPE}.tf
    fi
  
  done
  
  cd ./terraform-ami-module
  
  terraform remote config -backend=s3 \
                          -backend-config="bucket=-terraform-state-development" \
                          -backend-config="key=global/ami-id/terraform.tfstate" \
                          -backend-config="region=us-east-1"
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

##### Begin script #####
if [ "$#" -ne 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  help_message
fi

check_variables
run_packer
#update_terraform
git_tag
