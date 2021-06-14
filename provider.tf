# ----------------------------------------------------------------------------------------------------------------------
# REQUIRE A SPECIFIC TERRAFORM VERSION OR HIGHER
# This module has been updated with 0.12 syntax, which means it is no longer compatible with any versions below 0.12.
# ----------------------------------------------------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket = "terraform-state-devops-training-bucket"
    key    = "subnet/terraform.tfstate"
    region = "ap-southeast-1"
  }
  # Only allow Terraform version 12. Note that if you upgrade to a newer version, Terraform won't allow you to use an
  # older version, so when you upgrade, you should upgrade everyone on your team and your CI servers all at once.
  # also do not use Terraform version 11 as that will be failed
  required_version = ">= 0.12.0"
}

provider "aws" {
  region = var.aws_region
  # Provider version 2.X series is the latest, but has breaking changes with 1.X series.
  version = "~> 2.6"
}