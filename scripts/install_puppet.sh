#!/bin/bash
PATH="$PATH:/opt/puppetlabs/bin"
PUPPET_VERSION="8"
OS_FAMILY="$(cat /etc/*release | grep ^ID= | awk -F= '{ print $2}' | sed 's/"//g')"

ubuntu_puppet_install() {
  ubuntu_release="$(lsb_release -c | awk '{print $2}')"
  repo_package="puppet${PUPPET_VERSION}-release-${ubuntu_release}"

  # Wait for the dpkg/apt lock instead of failing if a boot-time job
  # (unattended-upgrades, cloud-init) is mid-transaction.
  echo 'DPKG::Lock::Timeout "120";' > /etc/apt/apt.conf.d/99lock-timeout

  echo -e "*********\n\n\tInstalling Puppet ${PUPPET_VERSION}\n\n*********"
  echo "**** Starting Puppet Install ****"
  wget https://apt.puppetlabs.com/${repo_package}.deb
  apt-get install -y ./${repo_package}.deb

  # apt-daily / unattended-upgrades can run a concurrent `apt-get update` on a
  # fresh boot and rewrite /var/lib/apt/lists out from under us. Retrying the
  # update+install together rebuilds the lists and recovers.
  retry_rpm_cmd "puppet-agent install" \
    bash -c 'apt-get update -y && apt-get install -y puppet-agent'
}

## Getting intermittent yum errors when some other process had a lock on the RPM database.
retry_rpm_cmd() {
  local description=$1
  shift
  local max_attempts=10
  local attempt=1
  local delay=15

  while [ $attempt -le $max_attempts ]; do
    if "$@"; then
      return 0
    fi

    if [ $attempt -eq $max_attempts ]; then
      echo "ERROR: ${description} failed after ${max_attempts} attempts"
      return 1
    fi

    echo "WARN: ${description} failed (attempt ${attempt}/${max_attempts}), retrying in ${delay}s..."
    sleep $delay
    attempt=$((attempt + 1))
    delay=$((delay * 2))
    if [ $delay -gt 120 ]; then
      delay=120
    fi
  done
}

amzn_puppet_install() {
  echo -e "*********\n\n\tInstalling Puppet ${PUPPET_VERSION}\n\n*********"
  amz_arch=$(uname -m)
  amz_version=$(cut -d':' -f6 /etc/system-release-cpe)
  ps aux | grep -E 'yum|dnf|rpm'
  retry_rpm_cmd "puppet repo install" \
    rpm -Uvh "https://yum.puppet.com/puppet${PUPPET_VERSION}/amazon/${amz_version}/${amz_arch}/puppet${PUPPET_VERSION}-release-1.0.0-9.amazon${amz_version}.noarch.rpm"

  retry_rpm_cmd "puppet-agent install" \
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
