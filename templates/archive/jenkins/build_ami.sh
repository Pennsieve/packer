#!/bin/bash -e

PATH="$PATH:/opt/puppetlabs/bin"
export GOPATH="/usr/lib/go-1.8/bin/"

install_puppet() {
  ubuntu_release="$(lsb_release -c | awk '{print $2}')"
  puppet_version="5"
  repo_package="puppet${puppet_version}-release-${ubuntu_release}"

  echo -e "\n\n**** Starting Puppet Install ****"
  wget https://apt.puppetlabs.com/${repo_package}.deb
  dpkg -i ${repo_package}.deb
  rm ${repo_package}.deb

  apt-get update -y
  apt-get install -y puppet-agent

  sed -i 's/"/"\/opt\/puppetlabs\/bin:/' /etc/environment
  echo "**** Completed Puppet Install ****"
}

install_sbt() {
  sbt_version=1.2.3
  curl -fsSL "https://github.com/sbt/sbt/releases/download/v$sbt_version/sbt-$sbt_version.tgz" | tar zx && \
  mv sbt /usr/local/share
  ln -s /usr/local/share/sbt/bin/sbt /usr/local/bin/sbt

  mkdir -p /home/ubuntu/.sbt/1.0
  cat <<EOF > /home/ubuntu/.sbt/.credentials
realm=Sonatype Nexus Repository Manager
host=nexus.blackfynn.io
user=${BLACKFYNN_CI_USER}
password=${BLACKFYNN_CI_PW}
EOF

  cat <<EOF > /home/ubuntu/.sbt/1.0/credentials.sbt
credentials += Credentials(Path.userHome / ".sbt" / ".credentials")
EOF

  chown -R ubuntu:ubuntu /home/ubuntu/.sbt
}

install_nextflow() {
  NEXTFLOW_DIR="/usr/local/share/nextflow/"
  USER="ubuntu"
  NEXTFLOW_INSTALL="nextflow_install.sh"

  mkdir $NEXTFLOW_DIR
  cd $NEXTFLOW_DIR
  chown $USER:$USER $NEXTFLOW_DIR

  sudo -u $USER curl -o $NEXTFLOW_INSTALL https://get.nextflow.io
  chmod +x $NEXTFLOW_INSTALL

  sudo -u $USER HOME="/home/$USER" ./$NEXTFLOW_INSTALL
  mv $NEXTFLOW_INSTALL nextflow
  ln -s $NEXTFLOW_DIR/nextflow /usr/local/bin/nextflow

  # This allows us to test local S3 resources via localstack
  echo "127.0.0.1       local-uploads-blackfynn.localhost" >> /etc/hosts
  echo "127.0.0.1       local-storage-blackfynn.localhost" >> /etc/hosts
}

install_puppet_modules() {
  echo -e "\n\n**** Installing Puppet Modules ****"
  set -e

  # helm requires specifc versions of archive and translate
  puppet module install -i ./modules puppet-archive --version 2.1.0
  puppet module install puppetlabs-translate --version 0.1.0

  puppet module install -i ./modules puppetlabs-kubernetes --version 3.0.0
  puppet module install -i ./modules juniorsysadmin-chromerepo --version 0.2.0
  puppet module install -i ./modules puppet-nodejs --version 5.0.0
  puppet module install -i ./modules puppetlabs-docker --version 2.0.0
  puppet module install -i ./modules puppetlabs-helm --version 1.0.1
  puppet module install -i ./modules puppetlabs-java --version 3.0.0
  puppet module install -i ./modules puppetlabs-ruby --version 1.0.0
  puppet module install -i ./modules puppet-python --version 2.1.1
  puppet module install -i ./modules inkblot-hashicorp --version 1.4.1
  set +e
  echo "**** Completed Installing Puppet Modules ****"
}

create_manifest() {
  /bin/cat << 'EOF' > ./local_manifest.pp
# I think this is already installed on EC2 instances. It
# is causing conflict with the Python package.
#class { 'awscli':
#  install_pkgdeps => false,
#  install_pip => false,
# }

class { 'docker':
  version => 'latest',
  docker_users => [ 'ubuntu' ],
}

class { 'docker::compose':
  version => '1.22.0',
  ensure => present,
}

class { 'helm::binary':
  version      => '2.7.0',
  install_path => '/usr/bin',
}

class { '::ruby': }

class { 'nodejs':
  repo_url_suffix => '8.x',
}

class { 'java':
  distribution => 'jdk',
}

class { 'python' :
  version    => 'system',
  pip        => 'present',
  dev        => 'present',
  virtualenv => 'present',
  gunicorn   => 'absent',
}

ensure_packages([ 'awscli', 'boto3', 'cython', 'twine' ], {
  ensure   => present,
  provider => 'pip',
  require  => Class['python'],
})


ensure_packages([ 'hiera-eyaml', 'puppet-lint' ], {
  ensure   => present,
  provider => 'gem',
  require  => Class['Ruby'],
})

include '::chromerepo'
apt::ppa { 'ppa:gophers/archive': }

apt::source { 'kubernetes':
  location => 'http://apt.kubernetes.io',
  repos    => 'main',
  release  => 'kubernetes-xenial',
  key      => {
    'id'     => 'D0BC747FD8CAF7117500D6FA3746C208A7317B0F',
    'source' => 'https://packages.cloud.google.com/apt/doc/apt-key.gpg',
  },
}

apt::source { 'yarn':
  location => 'https://dl.yarnpkg.com/debian',
  repos    => 'main',
  release  => 'stable',
  key      => {
    'id'     => '72ECF46A56B4AD39C907BBB71646B01B86E50310',
    'source' => 'https://dl.yarnpkg.com/debian/pubkey.gpg',
  },
}

$aptpackages = [ 'apache2-utils', 'bc', 'build-essential', 'cmake', 'dos2unix', 'ffmpeg', 'g++', 'golang-1.8-go',
                 'google-chrome-stable', 'jq', 'kubectl', 'ldap-utils', 'libcurl4-openssl-dev',
                 'libmysqlclient-dev', 'libpq-dev', 'postgresql-client', 'pylint', 'xvfb', 'unzip',
                  'vim', 'whois', 'yarn', 'zip' ]

package { $aptpackages:
  require => [ Apt::Source['kubernetes'],
               Apt::Source['yarn'],
               Class['chromerepo'],
               Class['nodejs'],
               Apt::Ppa['ppa:gophers/archive'] ]
}

file { '/home/ubuntu/.sbt':
  ensure => 'directory',
  mode   => '0644',
  owner  => 'ubuntu',
  group  => 'ubuntu'
}

file { '/home/ubuntu/.sbt/repositories':
  ensure  => 'present',
  mode    => '0644',
  owner   => 'ubuntu',
  group   => 'ubuntu',
  content => "[repositories]
local
blackfynn-ivy-proxy: https://nexus.blackfynn.io/repository/ivy-public/, [organization]/[module]/(scala_[scalaVersion]/)(sbt_[sbtVersion]/)[revision]/[type]s/[artifact](-[classifier]).[ext]
blackfynn-maven-proxy: https://nexus.blackfynn.io/repository/maven-public/
sonatype-snapshots: https://oss.sonatype.org/content/repositories/snapshots"
}

file { '/etc/profile.d/go_path.sh':
  ensure  => 'present',
  content => 'export "PATH=$PATH:/usr/lib/go-1.8/bin/:/usr/lib/go-1.8/bin/bin/"',
  mode    => '0644',
}

exec { 'go get github.com/roboll/helmfile':
  path    => ['/usr/lib/go-1.8/bin/', '/usr/bin/'],
  require => Package['golang-1.8-go'],
  onlyif  => ['test -z /usr/lib/go-1.8/bin/bin/helmfile']
}

class { 'hashicorp::terraform':
  version => '0.11.11'
}

class { 'hashicorp::packer':
  version => '1.3.3'
}
EOF
}


puppet_apply() {
  echo -e "\n\n**** Running \"puppet apply\" ****"
  puppet apply --color=false \
               --modulepath=./modules \
               --detailed-exitcodes \
               --disable_warnings deprecations \
               local_manifest.pp

  echo -e "\n\n**** Completed \"puppet apply\" ****"
}


get_versions() {
  echo -e "\n\n**** Software versions installed ****"

  java -version
  echo "Node version $(node -v)"
  docker version
  docker-compose --version
  packer version
  terraform version
  twine --version
}

######### START SCRIPT #########
[ "$(whoami)" = root ]     || { echo "Please run this script as root" && exit 1; }
[ ! -z "$(which puppet)" ] || { echo "Installing Puppet" && install_puppet; }

install_puppet_modules
create_manifest
puppet_apply

install_sbt
install_nextflow

get_versions
