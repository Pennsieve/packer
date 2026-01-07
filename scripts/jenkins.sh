#!/bin/bash -e

PATH="$PATH:/opt/puppetlabs/bin"
export GOPATH="/usr/lib/go-1.8/bin/"

NODE_VERSIONS=(14.21.1 18.17.1)

config_aws () {
  echo -e "\n\n**** Configure AWS ****"
 
  mkdir -p /home/ubuntu/.aws
  mkdir -p /root/.aws

  cat <<EOF > /home/ubuntu/.aws/config
[default]
region = us-east-1
EOF

  cat <<EOF > /root/.aws/config
[default]
region = us-east-1
EOF

  chown -R ubuntu:ubuntu /home/ubuntu/.aws
}

install_terraform() {
  tf_version=1.1.5

  echo -e "\n\n**** Installing Terraform $tf_version ****"
  cd $HOME

  sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
  wget -O- https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor | \
      sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

  gpg --no-default-keyring \
      --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
      --fingerprint

  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
      https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
      sudo tee /etc/apt/sources.list.d/hashicorp.list

  sudo apt update

  sudo apt-get install terraform=$tf_version

}

install_nvm() {
  echo -e "\n\n**** Installing NVM in ubuntu user ****"

  local versions="${NODE_VERSIONS[*]}"

  sudo -Hu ubuntu bash << EOSU
    cd \$HOME

    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh" # This loads nvm

    {
      echo 'export NVM_DIR="\$HOME/.nvm"'
      echo '[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"'
      echo '[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"'
    } >> "\${HOME}"/.profile

    for version in $versions; do
          echo "Installing Node \$version to \$NVM_DIR ..."
          nvm install \$version
          echo "npm cache: \$(npm config get cache)"
          echo "npm prefix: \$(npm config get prefix)"
          npm config list
          npm install -g yarn newman
    done

EOSU

}

install_sbt() {
  sbt_version=1.11.7

  echo -e "\n\n**** Installing sbt $sbt_version ****"
  cd $HOME
  curl -fsSL "https://github.com/sbt/sbt/releases/download/v$sbt_version/sbt-$sbt_version.tgz" | tar zx && \
  mv sbt /usr/local/share
  ln -s /usr/local/share/sbt/bin/sbt /usr/local/bin/sbt
}

install_puppet_modules() {
  echo -e "\n\n**** Installing Puppet Modules ****"
  set -e

  puppet module install -i ./modules puppetlabs-apt --version 9.1.0
  puppet module install -i ./modules puppet-nodejs --version 10.0.0
  puppet module install -i ./modules puppetlabs-docker --version 9.1.0
  puppet module install -i ./modules puppetlabs-java --version 10.1.2
  puppet module install -i ./modules puppet-python --version 7.0.0
  puppet module install -i ./modules treydock-golang --version 2.3.0 --ignore-dependencies

  set +e
  echo "**** Completed Installing Puppet Modules ****"


}

create_manifest() {
  echo -e "\n\n**** Creating puppet manifest ****"
 
  /bin/cat << 'EOF' > ./local_manifest.pp
class { 'docker':
  version => 'latest',
  docker_users => [ 'ubuntu' ],
}

class { 'docker::compose':
  ensure => present,
}

class { 'golang':
  version => '1.21.5',
}

class { 'java':
  package => 'openjdk-8-jdk',
}

class { 'python' :
  version    => 'python3',
  pip        => 'present',
  dev        => 'absent',
  gunicorn   => 'absent',
}

$aptpackages = [ 'git', 'apache2-utils', 'bc', 'build-essential', 'cmake', 'dos2unix', 'ffmpeg', 'g++',
                 'jq', 'ldap-utils', 'libcurl4-openssl-dev', 'libmysqlclient-dev',
                 'libpq-dev', 'postgresql-client', 'pylint', 'xvfb', 'unzip', 'vim', 'whois', 'zip' ]

package { $aptpackages:ensure => 'installed' }

ensure_packages([ 'awscli', 'boto3', 'cython', 'twine' ], {
  ensure   => present,
  provider => 'pip',
  require  => Class['python'],
})

file { '/etc/profile.d/go_path.sh':
  ensure  => 'present',
  content => 'export "PATH=$PATH:/usr/lib/go-1.8/bin/:/usr/lib/go-1.8/bin/bin/"',
  mode    => '0644',
}

EOF
}

puppet_apply() {
  echo -e "\n\n**** Running \"puppet apply\" ****"
  puppet apply --color=false \
               --modulepath=./modules \
               --disable_warnings deprecations \
               local_manifest.pp
  echo $?

  echo -e "\n\n**** Completed \"puppet apply\" ****"
}

clean_up() {
  echo -e "\n\n**** Cleaning up $HOME for AMI ****"
  cd $HOME # this will be /root
  shopt -s dotglob # dotglob matches dot files, but not . or ..
  chown -R ubuntu:ubuntu $HOME/* || true
  shopt -u dotglob
  rm -rf local_manifest.pp modules || true
}

get_nvm_versions() {
  local versions="${NODE_VERSIONS[*]}"

  sudo -Hu ubuntu bash << EOSU
    cd \$HOME
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"

    for version in $versions; do
      nvm use \$version > /dev/null
      echo "Node \$(node -v): yarn \$(yarn -v 2>/dev/null || echo 'not found'), newman \$(newman -v 2>/dev/null || echo 'not found')"
    done

    echo "Default: \$(nvm alias default | awk '{print \$3}')"
EOSU
}

get_versions() {
  echo -e "\n\n*************************************"
  echo -e "*    Software versions installed    *"
  echo -e "*************************************"

  echo -e "\n******* Java version information *******"
  java -version

  echo -e "\n******* Docker version information *******"
  docker version
  docker-compose --version

  echo -e "\n******* Node and node modules version information *******"
  get_nvm_versions

  echo -e "\n******* sbt version information *******"
  # warms the sbt cache a little for the ubuntu user
  sudo -Hu ubuntu bash -c 'cd ~ && sbt --allow-empty sbtVersion && rm -fr ~/project ~/target'

  echo -e "\n******* Terraform version information *******"
  terraform version

  echo -e "\n******* Twine version information *******"
  twine --version

  echo -e "\n******* Golang version information *******"
  go version
}

######### START SCRIPT #########
[ "$(whoami)" = root ]     || { echo "Please run this script as root" && exit 1; }
[ ! -z "$(which puppet)" ] || { echo "Installing Puppet" && install_puppet; }

cd $HOME
config_aws
create_manifest
install_puppet_modules
install_nvm
install_terraform
puppet_apply
install_sbt

get_versions
clean_up
