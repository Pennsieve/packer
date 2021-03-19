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
  version => '0.11.8'
}

class { 'hashicorp::packer':
  version => '1.3.1'
}
