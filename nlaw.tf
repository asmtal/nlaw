variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "node_count" {}
variable "target_source" {}
variable "rotate" {}
variable "instance_type" {}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  region = terraform.workspace
}

resource "aws_default_vpc" "vpc" {

}

data "aws_availability_zones" "azs" {

}

data "aws_subnet" "subnet" {
  availability_zone_id = data.aws_availability_zones.azs.zone_ids[0]
}

data "aws_iam_policy_document" "ec2_assume_role" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "gateway" {
  name               = "nlaw-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "gateway_amazon_ssm_managed_instance_core" {
  role       = aws_iam_role.gateway.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "gateway" {
  name = "nlaw-${terraform.workspace}"
  role = aws_iam_role.gateway.name
}

resource "aws_security_group" "gateway" {
  name = "nlaw-${terraform.workspace}"

  vpc_id = aws_default_vpc.vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "ALL"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

module "nlaw" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.17.0"

  name = "nlaw-${terraform.workspace}-${sha1(data.cloudinit_config.nlaw.rendered)}"

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [
    aws_security_group.gateway.id
  ]

  root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 10
    }
  ]

  subnet_ids = [data.aws_subnet.subnet.id]
  iam_instance_profile = aws_iam_instance_profile.gateway.name

  user_data_base64 = base64encode(data.cloudinit_config.nlaw.rendered)

  count = var.node_count
}


data "cloudinit_config" "nlaw" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "cloud-config"
    content = templatefile("cloudinit.yaml", {target_source = var.target_source, rotate = var.rotate})
    merge_type = "list(append)+dict(recurse_array)+str()"
  }
}
