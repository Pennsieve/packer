#!/bin/bash -ex

mkdir /docker_scratch
mkdir -p /root/.docker
mkdir -p /root/.aws

yum -y update
yum install -y python27-pip
pip install awscli

install_puppet() {
  OS_RELEASE="6"
  echo "**** Starting Puppet Install ****"

  rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-$OS_RELEASE.noarch.rpm
  yum -y install puppet-agent

  /opt/puppetlabs/bin/puppet config set --section main server ops-pup-master-use1.blackfynn.io
  /opt/puppetlabs/bin/puppet resource service puppet enable=true
}

install_puppet
########################
echo "Creating AWS CLI config file."

cat << EOF > /root/.aws/config
[default]
region = us-east-1
EOF

########################
echo "Configuring Docker and ECS dameon."

DOCKER_REGISTRY_URL="$(/usr/local/bin/aws --output text ssm get-parameter --name ops-ci-docker-hub-url --query 'Parameter'.Value)"
DOCKER_REGISTRY_AUTH="$(/usr/local/bin/aws --output text ssm get-parameter --name ops-ci-docker-hub-auth --with-decryption --query 'Parameter'.Value)"
DOCKER_REGISTRY_EMAIL="$(/usr/local/bin/aws --output text ssm get-parameter --name ops-ci-docker-hub-email --query 'Parameter'.Value)"

cat << EOF >> /etc/ecs/ecs.config
ECS_ENGINE_AUTH_TYPE=dockercfg
ECS_ENGINE_AUTH_DATA={"$DOCKER_REGISTRY_URL":{"auth":"$DOCKER_REGISTRY_AUTH","email":"$DOCKER_REGISTRY_EMAIL"}}
EOF

cat << EOF > /opt/bf-ecs-cluster.sh
ECS_CLUSTER_NAME=\$(cat /etc/ecs/ecs.config | grep ECS_CLUSTER | awk -F= '{print \$2}' | awk -F- '{print \$1"-"\$2"-"\$3"-"\$4}')

if [ -z "\$(grep \$ECS_CLUSTER_NAME /etc/sysconfig/docker)" ]; then
  sed -i "/^OPTIONS/c\OPTIONS=\"--default-ulimit nofile=1024:4096 --log-driver awslogs --log-opt awslogs-group=/aws/ecs/\$ECS_CLUSTER_NAME\"" /etc/sysconfig/docker
fi
EOF

chmod +x /opt/bf-ecs-cluster.sh

cat << EOF > /etc/cron.d/bf-ecs-cluster
SHELL=/bin/sh
* * * * * root /opt/bf-ecs-cluster.sh
EOF

########################

echo "Stoping ECS and cleaning up."

rm -rf /var/lib/ecs/data/ecs_agent_data.json
