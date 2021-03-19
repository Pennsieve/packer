# Jenkins

## Secrets

In order to build an ami for Jenkins you will need to have a `secrets.json`
file in the `packer/jenkins` directory defining 2 variables:

* `BLACKFYNN_CI_USER`
* `BLACKFYNN_CI_PW`

## Local Testing

Test Puppet modules with Vagrant.

### Requirements

- VirtualBox
- Vagrant
  - `vagrant plugin install vagrant-vbguest`
