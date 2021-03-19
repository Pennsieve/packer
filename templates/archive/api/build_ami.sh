#!/bin/bash -e

install_puppet() {
  echo -e "*********\n\n\tInstalling Puppet ${puppet_version}\n\n*********"

  rpm -Uvh https://yum.puppet.com/puppet5/puppet5-release-el-6.noarch.rpm
  yum install -y puppet-agent
  /opt/puppetlabs/bin/puppet config set --section main server ops-pup-master-use1.blackfynn.io
  /opt/puppetlabs/bin/puppet resource service puppet enable=true


  sed -i 's/"/"\/opt\/puppetlabs\/bin:/' /etc/environment

  # Catch puppet changes exit code 2
  set +e
  /opt/puppetlabs/bin/puppet agent -t
  PUPPET_EXIT_CODE=$?

  if [ "$PUPPET_EXIT_CODE" -ne 0 ] ; [ "$PUPPET_EXIT_CODE" -ne 2 ]; then
    echo "None 0 exit code during Puppet"
    echo $PUPPET_EXIT_CODE
    exit $PUPPET_EXIT_CODE
  fi
  set -e
}

system_config() {
  cat <<EOF > /etc/vim/vimrc.local
colorscheme desert
EOF

  cat <<'EOF' >> /etc/profile
export VISUAL=vim
export EDITOR="\\$VISUAL"
EOF
}

#### START BUILD SCRIPT ####
echo -e "*********\n\n\tUpdating and installing base packages\n\n*********"
yum upgrade
install_puppet
#system_config

#### Sanatize AMI ####
rm -rf /etc/puppetlabs/puppet/ssl
rm -rf /var/lib/cloud/instances/
rm -rf /var/log/messages /var/log/cloud* /var/log/audit/* /var/log/maillog /var/log/cron /var/log/messages-*
