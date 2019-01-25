
# This sets providor and stop region prompts
provider "aws" {
  region = "us-east-1"
  skip_region_validation  = true
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}