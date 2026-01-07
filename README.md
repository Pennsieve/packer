# Packer

## How to use this repo

[Packer](https://www.packer.io/intro/index.html) allows you to build Amazon Machine Images (AMI) in a reproducible
fashion. By commiting the `packer-output.log` and creating a tag, we can track and audit the software in our AMIs.

### Repository Breakdown

- `create_ami.sh` script - pass in the type of AMI you want to build. Run without any options to view the supported
  build types
- `templates` directory - contains `json` files that Packer uses to create AMIs for ecs, jenkins, etc
- `scripts` directory - contains the scripts that will be run on the EC2 instance during a specific build

### Example: Build a New ECS AMI

1. [Download Packer](https://www.packer.io/downloads.html)
2. Run `packer plugins install github.com/hashicorp/amazon`. This is only necessary when you first install Packer.
3. Run `./create_ami.sh ecs`
4. Issue the git commands when the build completes to create a tagged release of the AMI

## Testing Builds

Requirement: AWS CLI v2 and jq

The test script `test-on-ec2.sh` creates a new EC2 instance in the pennsieve-cc account using a provided template to
determine the base AMI and runs provided build scripts to test the build.

To test a build script:

Copy `test.env.example` to `test.env` and update `test.env` with real values.

Update the `test-on-ec2.sh` to point to the template and scripts you want to test. The following example will
test a Jenkins build:

``` 
...
  SCRIPTS=(
    "scripts/install_puppet.sh"
    "scripts/jenkins.sh"
  )
  TEMPLATE_FILE="${SCRIPT_DIR}/templates/jenkins.json"
...
```

Then run `test-on-ec2.sh` to build and example instance and examine the console output. The output is also written to
`test-output.log`. The test script takes care of terminating the test instance.

Run `test-on-ec2.sh --keep` to keep the instance running after the script exits. You are then responsible for
terminating the instance. You can ssh into the instance to look around using the `ssh` command output by the test
script. 

