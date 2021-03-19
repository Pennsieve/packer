# Jenkins Packer Build

## jenkins-ami-34 - 2018-10-31

* Upgrade terraform to v0.11.10

## jenkins-ami-33 - 2018-10-16

* Set `spot_price` to `auto` in packer config as now required by AWS API
* Remove `encrypted: true` flag from `ami_block_device_mappings`. This
  was conflicting with the `encrypt_boot: true` flag because they refer
  to the same device; `/dev/sda1`.
* Configure credentials for use with SBT:
  * Added vars `BLACKFYNN_CI_USER`, `BLACKFYNN_CI_PW` to be supplied via local
    json variable file
  * Configure `/home/ubuntu/.sbt/.credentials` and
    `/home/ubuntu/.sbt/1.0/credentials.sbt` via `build_ami.sh`
  * Create `/home/ubuntu/.sbt` and configure `/home/ubuntu/.sbt/repositories`
    via Puppet
* Update packages:
  * Docker to latest
  * Packer to v1.3.1
  * SBT to 1.2.3
* Correct typo in `echo` command in `get_versions()` function
