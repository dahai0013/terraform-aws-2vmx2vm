# Create VPC-iGW-VGW + Subnet + Linux and vMX Instance
# 0- AWS access and secret key to access AWS
# 1- create an VPC
# 1a- create an Internet Gateway
# 1b- create an Route in the RT
# 1c- create Mgt Security Groups
# 1d- create IPsec Security Groups
# 2a- create Private subnet ( to VM instances )
# 2b- create Public IPSec subnet ( for Data IPSec Tunnel)
# 2c- create Public Mgmt subnet ( for vMX Mgmt)
# 2d- associate Public subnet to Main routing table
# 2e- associate Mgmt subnet to Main routing table
# 3- Create an Key pair to access the VM
# 4- create an Linux instance
# 5- create an vMX Instance
# 6- add Network interface to the vMX Instance

# define variables and point to terraform.tfvars
variable "my_vpc_name" {}
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable pub_sub0 {}
variable pub_sub1 {}
variable pri_sub2 {}
variable pri_sub3 {}
variable my_key_name {}
variable my_vmx_ami {}
variable my_ubuntu_ami {}
variable my_ubuntu_instance_type {}

# 0- AWS access and secret key to access AWS
provider "aws" {
        access_key = "${var.access_key}"
        secret_key = "${var.secret_key}"
        region = "${var.region}"
}

# 1- create an VPC in aws
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags {
    Name = "${var.my_vpc_name}"
  }
}

# 1a- create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "${var.my_vpc_name}-igw"
  }
}

# 1b- create an Route in the RT
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

# 1c- create Mgt Security Groups
resource "aws_security_group" "allow_ssh" {
  name = "allow_inbound_SSH"
  description = "Allow inbound SSH traffic from any IP@"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    #prefix_list_ids = ["pl-12c4e678"]
  }
  tags {
    Name = "Allow SSH"
    }
}

# 1d- create IPsec Security Groups
#UDP packets on port 500 (and port 4500 if using NAT traversal)
resource "aws_security_group" "allow_IPSec" {
  name = "allow_inbound_IPSec"
  description = "Allow inbound IPSec traffic from any IP@"
  vpc_id = "${aws_vpc.vpc.id}"
  ingress {
    from_port = 500
    to_port = 500
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags {
    Name = "Allow IPSec"
    }
}

# 2a-1 create Private subnet ( to VM1 instances )
resource "aws_subnet" "private1" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.pri_sub2}"
  availability_zone = "${aws_subnet.public.availability_zone }"
  tags {
    Name = "${var.my_vpc_name}-private1"
  }
}

# 2a-2 create Private subnet ( to VM2 instances )
resource "aws_subnet" "private2" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.pri_sub3}"
  availability_zone = "${aws_subnet.public.availability_zone }"
  tags {
    Name = "${var.my_vpc_name}-private2"
  }
}

# 2b- create Public IPSec subnet ( for Data IPSec Tunnel )
resource "aws_subnet" "public" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.pub_sub0}"
  # availability_zone =
  tags {
    Name = "${var.my_vpc_name}-public"
  }
}

# 2c- create Public Mgmt subnet ( for vMX Mgmt)
resource "aws_subnet" "mgmt" {
  vpc_id = "${aws_vpc.vpc.id}"
  cidr_block = "${var.pub_sub1}"
  availability_zone = "${aws_subnet.public.availability_zone }"
  tags {
    Name = "${var.my_vpc_name}-Mgmt"
  }
}

# 2d- associate Public IPsec subnet to Main routing table
resource "aws_route_table_association" "assoc-public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_vpc.vpc.main_route_table_id}"
  #route_table_id = #"${aws_route_table..id}"
}

# 2e- associate Public Mgmt subnet to Main routing table
resource "aws_route_table_association" "assoc-mgmt" {
  subnet_id      = "${aws_subnet.mgmt.id}"
  route_table_id = "${aws_vpc.vpc.main_route_table_id}"
  #route_table_id = #"${aws_route_table..id}"
}

# JLK prefer to use one already created manually ( easier )
#
#3- Create an Key pair to access the VM
#resource "aws_key_pair" "admin_key" {
#  key_name   = "${var.my_key_name}"
### JLK modif:  key_name = "admin_key"
#  public_key = "ssh-rsa AAAAB3[…]"
#}

# 4-1 create an Ubuntu instance
resource "aws_instance" "ubuntu1" {
        ami = "${var.my_ubuntu_ami}"
        instance_type = "${var.my_ubuntu_instance_type}"
        key_name = "${var.my_key_name}"
        subnet_id = "${aws_subnet.private1.id}"
        security_groups = ["${aws_security_group.allow_ssh.id}"]
        associate_public_ip_address = true
        availability_zone = "${aws_subnet.public.availability_zone }"
        tags {
         Name = "${var.my_vpc_name}-Ubuntu1-instance"
        }
}

# 4-2 create an Ubuntu instance
resource "aws_instance" "ubuntu2" {
        ami = "${var.my_ubuntu_ami}"
        instance_type = "${var.my_ubuntu_instance_type}"
        key_name = "${var.my_key_name}"
        subnet_id = "${aws_subnet.private2.id}"
        security_groups = ["${aws_security_group.allow_ssh.id}"]
        associate_public_ip_address = true
        availability_zone = "${aws_subnet.public.availability_zone }"
        tags {
         Name = "${var.my_vpc_name}-Ubuntu2-instance"
        }
}

# 5-1 create an vMX instance
resource "aws_instance" "vMX1" {
        ami = "${var.my_vmx_ami}"
        instance_type = "m4.xlarge"
        key_name = "${var.my_key_name}"
        subnet_id = "${aws_subnet.mgmt.id}"
        security_groups= ["${aws_security_group.allow_ssh.id}"]
        associate_public_ip_address = true
        availability_zone = "${aws_subnet.public.availability_zone }"
        tags {
         Name = "${var.my_vpc_name}-vMX1"
        }
}

# 5-2 create an vMX2 instance
resource "aws_instance" "vMX2" {
        ami = "${var.my_vmx_ami}"
        instance_type = "m4.xlarge"
        key_name = "${var.my_key_name}"
        subnet_id = "${aws_subnet.mgmt.id}"
        security_groups= ["${aws_security_group.allow_ssh.id}"]
        associate_public_ip_address = true
        availability_zone = "${aws_subnet.public.availability_zone }"
        tags {
         Name = "${var.my_vpc_name}-vMX2"
        }
}

# 6-1a add Network interface to the vMX1 Instance
resource "aws_network_interface" "vMX1_ge0-0-0" {
  subnet_id       = "${aws_subnet.public.id}"
  #private_ips     = ["10.0.0.2"]
  security_groups = ["${aws_security_group.allow_IPSec.id}"]
  attachment {
    instance     = "${aws_instance.vMX1.id}"
    device_index = 1
  }
}
# 6-1b add Network interface to the vMX1 Instance
resource "aws_network_interface" "vMX1_ge0-0-1" {
  subnet_id       = "${aws_subnet.private2.id}"
  #private_ips     = ["10.0.0.2"]
  security_groups = ["${aws_security_group.allow_IPSec.id}"]
  attachment {
    instance     = "${aws_instance.vMX1.id}"
    device_index = 2
  }
}

# 6-2a add Network interface to the vMX2 Instance
resource "aws_network_interface" "vMX2_ge0-0-0" {
  subnet_id       = "${aws_subnet.public.id}"
  #private_ips     = ["10.0.0.2"]
  security_groups = ["${aws_security_group.allow_IPSec.id}"]
  attachment {
    instance     = "${aws_instance.vMX2.id}"
    device_index = 1
  }
}

# 6-2b add Network interface to the vMX2 Instance
resource "aws_network_interface" "vMX2_ge0-0-1" {
  subnet_id       = "${aws_subnet.private2.id}"
  #private_ips     = ["10.0.0.2"]
  security_groups = ["${aws_security_group.allow_IPSec.id}"]
  attachment {
    instance     = "${aws_instance.vMX2.id}"
    device_index = 2
  }
}