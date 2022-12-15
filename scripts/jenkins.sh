#!/bin/bash -e

PATH="$PATH:/opt/puppetlabs/bin"
export GOPATH="/usr/lib/go-1.8/bin/"

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

  chown ubuntu:ubuntu /home/ubuntu/.aws/config
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

install_yarn() {
  echo -e "\n\n**** Installing Yarn ****"
  cd $HOME
  npm install -g yarn
}

install_sbt() {
  sbt_version=1.2.8

  echo -e "\n\n**** Installing sbt $sbt_version ****"
  cd $HOME
  curl -fsSL "https://github.com/sbt/sbt/releases/download/v$sbt_version/sbt-$sbt_version.tgz" | tar zx && \
  mv sbt /usr/local/share
  ln -s /usr/local/share/sbt/bin/sbt /usr/local/bin/sbt

  sbt sbtVersion
}

#install_nextflow() {
#  NEXTFLOW_DIR="/usr/local/bin/"
#
#  echo -e "\n\n**** Installing Nextflow ****"
#  cd $NEXTFLOW_DIR
#
#  curl -fsSL https://get.nextflow.io | bash &>/dev/null
#
#  # This allows us to test local S3 resources via localstack
#  echo "127.0.0.1       local-uploads-pennsieve.localhost" >> /etc/hosts
#  echo "127.0.0.1       local-storage-pennsieve.localhost" >> /etc/hosts
#
#  /usr/local/bin/nextflow
#
#  cd $HOME
#}

#install_kube_tools() {
#  kops_version="1.12.2"
#  kubectl_version="1.15.0"
#
#  echo -e "\n\n**** Installing kops ****"
#  curl -LO https://github.com/kubernetes/kops/releases/download/${kops_version}/kops-linux-amd64
#  chmod +x kops-linux-amd64
#  mv kops-linux-amd64 /usr/local/bin/kops
#
#  echo -e "\n\n**** Installing kubectl ****"
#  curl -LO https://storage.googleapis.com/kubernetes-release/release/v${kubectl_version}/bin/linux/amd64/kubectl
#  chmod +x kubectl
#  mv kubectl /usr/local/bin/kubectl
#}

install_puppet_modules() {
  echo -e "\n\n**** Installing Puppet Modules ****"
  set -e

  puppet module install -i ./modules puppetlabs-apt --version 8.0.2
  puppet module install -i ./modules puppet-nodejs --version 9.0.1
  puppet module install -i ./modules puppetlabs-docker --version 5.1.0
  puppet module install -i ./modules puppetlabs-java --version 9.0.1
  puppet module install -i ./modules puppet-python --version 6.4.0
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
  version => '1.24.1',
  ensure => present,
}

#class { '::ruby': }

class { 'nodejs': }

#class { 'yarn': }

class { 'golang':
  version => '1.18',
}

class { 'java':
  package => 'openjdk-8-jdk',
}

class { 'python' :
  version    => 'system',
  pip        => 'present',
  dev        => 'absent',
  gunicorn   => 'absent',
}


apt::source { 'google-chrome':
  location => 'http://dl.google.com/linux/chrome/deb/',
  repos   => 'main',
  release => 'stable',
  key      => {
    'id'     => '4CCA1EAF950CEE4AB83976DCA040830F7FAC5991',
    'source' => 'http://dl-ssl.google.com/linux/linux_signing_key.pub'
  },
}

apt::ppa { 'ppa:gophers/archive': }

$aptpackages = [ 'apache2-utils', 'bc', 'build-essential', 'cmake', 'dos2unix', 'ffmpeg', 'g++', 'golang-1.8-go',
                 'google-chrome-stable', 'jq', 'ldap-utils', 'libcurl4-openssl-dev', 'libmysqlclient-dev',
                 'libpq-dev', 'postgresql-client', 'python3-pip', 'pylint', 'xvfb', 'unzip', 'vim', 'whois', 'zip' ]

package { $aptpackages:
  require => [
    Apt::Source['google-chrome'],
    Apt::Ppa['ppa:gophers/archive']
  ]
}

ensure_packages([ 'awscli', 'boto3', 'cython', 'twine' ], {
  ensure   => present,
  provider => 'pip',
  require  => Class['python'],
})

#ensure_packages([ 'hiera-eyaml', 'puppet-lint' ], {
#  ensure   => present,
#  provider => 'gem',
#  require  => Class['ruby'],
#})

ensure_packages([ 'newman' ], {
  ensure   => present,
  provider => 'npm',
  require  => Class['nodejs'],
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
  echo -e "\n\n**** Cleaning up AMI ****"
  cd $HOME
  chown -R ubuntu:ubuntu $HOME/.* || true
  chown -R ubuntu:ubuntu $HOME/*  || true
  rm -rf project modules || true
  rm local_manifest.pp || true
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

#  echo -e "\n******* Kops version information *******"
#  kops version
#
#  echo -e "\n******* Nextflow version information *******"
#  nextflow -v

  echo -e "\n******* Node and node modules version information *******"
  echo "Node version $(node -v)"
  echo "Newman version $(newman -v)"

  echo -e "\n******* Packer version information *******"
  packer version

  echo -e "\n******* sbt version information *******"
  sbt sbtVersion

  echo -e "\n******* Terraform version information *******"
  terraform version

  echo -e "\n******* Twine version information *******"
  twine --version

  echo -e "\n******* Yarn version information *******"
  yarn -v

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
puppet_apply

install_terraform
install_yarn
install_sbt

get_versions
clean_up
