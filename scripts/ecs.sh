#!/bin/bash -e

mkdir /docker_scratch
mkdir -p /root/.docker
mkdir -p /root/.aws

yum -y update
yum install -y python27-pip jq
pip install awscli

create_aws_cli_config_file() {
  echo "Creating AWS CLI config file."

  cat << EOF > /root/.aws/config
[default]
region = us-east-1
EOF
}

get_versions() {
  echo -e "\n\n**** Software versions installed ****"

  docker version
  service --status-all
  ecs_agent_version=$(curl http://localhost:51678/v1/metadata | jq -r '.Version')
  echo $ecs_agent_version
}

create_aws_cli_config_file
get_versions

rm -rf /var/lib/ecs/data/ecs_agent_data.json
