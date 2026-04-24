#!/bin/bash -e

mkdir /docker_scratch
mkdir -p /root/.docker
mkdir -p /root/.aws

verify_preinstalled_tools() {
  echo -e "*********\n\n\tVerifying pre-installed tools\n\n*********"

  if command -v jq >/dev/null 2>&1; then
    echo "jq: $(jq --version) ($(command -v jq))"
  else
    echo "ERROR: jq not found on PATH"
    return 1
  fi

  if command -v aws >/dev/null 2>&1; then
    echo "aws: $(aws --version) ($(command -v aws))"
  else
    echo "ERROR: aws CLI not found on PATH"
    return 1
  fi
}

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
  systemctl list-units --type=service --state=running --no-pager

  echo -n "ECS agent package: "
  rpm -q ecs-init --queryformat '%{VERSION}-%{RELEASE}\n' 2>/dev/null || echo "not installed"
}

verify_preinstalled_tools
create_aws_cli_config_file
get_versions

rm -rf /var/lib/ecs/data/ecs_agent_data.json
