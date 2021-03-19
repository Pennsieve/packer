
variable "aws_account" {}

variable "aws_region" {}

variable "environment_name" {}

variable "vpc_name" {}

variable "service_name" {
  default = "packer"
}

locals {
  hostname        = "${var.environment_name}-${var.service_name}-${data.terraform_remote_state.vpc.aws_region_shortname}"
  resource_prefix = "${var.environment_name}-${var.service_name}"

  common_tags = {
    aws_account      = "${var.aws_account}"
    aws_region       = "${var.aws_region}"
    environment_name = "${var.environment_name}"
    service_name     = "${var.service_name}"
  }
}
