data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-${var.ubuntu_version}*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  owners = ["099720109477"] # use official Ubuntu images provided by Canonical
}

data "aws_region" "this" {}
