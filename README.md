# Packer

## How to use this repo

[Packer](https://www.packer.io/intro/index.html) allows you to build Amazon Machine Images (AMI) in a reproducible fashion. By commiting the `packer-output.log` and creating a tag, we can track and audit the software in our AMIs. 

### Repository Breakdown

- `create_ami.sh` script - pass in the type of AMI you want to build. Run without any options to view the supported build types
- `templates` directory - contains `json` files that Packer uses to create AMIs for ecs, jenkins, etc
- `scripts` directory - contains the scripts that will be run on the EC2 instance during a specific build

### Example: Build a New ECS AMI

1. [Download Packer](https://www.packer.io/downloads.html)
2. Run `./create_ami.sh ecs`
3. Issue the git commands when the build completes to create a tagged release of the AMI

## Testing Builds

Requirement: vagrant

To test a buid script, update the `Vagrantfile` to point to the script you want to test. The following example will test a Jenkins build:

``` 
...
  config.vm.provision "shell", path: "scripts/install_puppet.sh"
  config.vm.provision "shell", path: "scripts/jenkins.sh"
...
```
