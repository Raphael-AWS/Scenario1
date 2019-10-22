# Terraform state will be stored in S3
terraform {
  backend "s3" {
    bucket = "terraform-jenkins-s3"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
#setup Provider
provider "aws" {
  region = "${var.aws_region}"
}
#VPC
resource "aws_vpc" "vpc_tuto" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "TestVPC"
  }
}

#public subnet
resource "aws_subnet" "public_subnet_us-east-1a" {
  vpc_id                  = "${aws_vpc.vpc_tuto.id}"
  cidr_block              = "${var.public_subnet_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
  tags = {
   Name =  "Public Subnet az 1a"
  }
}
#Create EIP for Internet Gateway
resource "aws_eip" "tuto_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.gw"]
}
#IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc_tuto.id}"
  tags = {
        Name = "InternetGateway"
    }
}
# IAM Role
resource "aws_iam_role" "test_role" {
  name = "test_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags = {
      tag-key = "terraform - IAM Role"
  }
}
resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "${aws_iam_role.test_role.name}"
}
resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = "${aws_iam_role.test_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

 ### Creating Security Group for Web EC2
resource "aws_security_group" "webinstance" {
  name = "terraform-webinstanceSG"
  description = "Allow incoming HTTP connections."

    ingress {
        from_port = 80
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = -1
        to_port = -1
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress { # SQL Server
        from_port = 1433
        to_port = 1433
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }
    egress { # MySQL
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }

    vpc_id = "${aws_vpc.vpc_tuto.id}"

    tags = {
        Name = "Terraform-WebServerSG"
    }
}

### Creating EC2 Web instance
resource "aws_instance" "web" {
  ami               = "${lookup(var.amis,var.aws_region)}"
  count             = "${var.Count}"
  key_name               = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.webinstance.id}"]
  source_dest_check = false
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public_subnet_us-east-1a.id}"
  iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
tags = {
    Name = "${format("web-%03d", count.index + 1)}"
  }
}
