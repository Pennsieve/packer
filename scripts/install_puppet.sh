#!/bin/bash
PATH="$PATH:/opt/puppetlabs/bin"
PUPPET_VERSION="6"
OS_FAMILY="$(cat /etc/*release | grep ^ID= | awk -F= '{ print $2}' | sed 's/"//g')"

ubuntu_puppet_install() {
  ubuntu_release="$(lsb_release -c | awk '{print $2}')"
  repo_package="puppet${PUPPET_VERSION}-release-${ubuntu_release}"

  echo -e "*********\n\n\tInstalling Puppet ${PUPPET_VERSION}\n\n*********"
  echo "**** Starting Puppet Install ****"
  wget https://apt.puppetlabs.com/${repo_package}.deb
  dpkg -i ${repo_package}.deb
  rm ${repo_package}.deb

  apt-get update -y
  apt-get install -y puppet-agent
}

amzn_puppet_install() {
  echo -e "*********\n\n\tInstalling Puppet ${PUPPET_VERSION}\n\n*********"

  rpm -Uvh https://yum.puppet.com/puppet${PUPPET_VERSION}/puppet${PUPPET_VERSION}-release-el-6.noarch.rpm
  yum install -y puppet-agent
}

post_install() {
  cat << EOF > /etc/cron.d/bf-facts
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
@reboot   root    echo "instance_id=\$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)" > /opt/puppetlabs/facter/facts.d/bf-facts.txt
@reboot   root    echo "ami_id=\$(curl --silent http://169.254.169.254/latest/meta-data/ami-id)" >> /opt/puppetlabs/facter/facts.d/bf-facts.txt
EOF

  /opt/puppetlabs/bin/puppet config set --section main server ops-pup-master-use1.pennsieve.io
  /opt/puppetlabs/bin/puppet resource service puppet ensure=stopped enable=false

  sed -i 's/"/"\/opt\/puppetlabs\/bin:/' /etc/environment
}

######### START SCRIPT #########
[ "$(whoami)" = root ]   || { echo "Please run this script as root" && exit 1; }
[ -z "$(which puppet)" ] || { echo "Puppet is already installed" && exit 0; }

case $OS_FAMILY in
  ubuntu|amzn)
    ${OS_FAMILY}_puppet_install
    ;;
  ****)
    echo "Only ubuntu and amzn operating systems are supported."
    exit 1
    ;;
esac
