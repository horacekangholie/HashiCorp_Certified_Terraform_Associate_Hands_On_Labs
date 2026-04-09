# Configure the AWS Provider
provider "aws" {
  region = "ap-southeast-1"
  default_tags {
    tags = {
      Environment = terraform.workspace
      Owner       = "Acme"
      Provision   = "Terraform"
    }
  }
}

# Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

# data "http" "my_ip" {
#   url = "https://checkip.amazonaws.com"
# }

# Local values to avoid hardcoding and repetition
locals {
  team        = "api_mgmt_dev"
  application = "corp_api"
  server_name = "ec2-${var.environment}-api-${var.variables_sub_az}"
}

# Define the VPC
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = var.vpc_name
    Environment = "demo_environment"
    Terraform   = "true"
    Region      = data.aws_region.current.id
  }
}

# Deploy the private and public subnets
resource "aws_subnet" "private_subnets" {
  for_each          = var.private_subnets
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone = tolist(data.aws_availability_zones.available.names)[each.value]
  tags = {
    Name      = each.key
    Terraform = "true"
  }
}
resource "aws_subnet" "public_subnets" {
  for_each                = var.public_subnets
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 100)
  availability_zone       = tolist(data.aws_availability_zones.available.names)[each.value]
  map_public_ip_on_launch = true
  tags = {
    Name      = each.key
    Terraform = "true"
  }
}

# Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
    #nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_public_rtb"
    Terraform = "true"
  }
}
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    # gateway_id = aws_internet_gateway.internet_gateway.id
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_private_rtb"
    Terraform = "true"
  }
}

# Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}
resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}

# Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "demo_igw"
  }
}

# Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  # vpc = true
  domain     = "vpc"
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "demo_igw_eip"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_subnet.public_subnets]
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id # NAT Gateway in 2-nd Subnet
  tags = {
    Name = "demo_nat_gateway"
  }
}

# Terraform Data Block - To Lookup Latest Ubuntu 20.04 AMI Image
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

# Terraform Resource Block - To Build EC2 instance in Public Subnet
# resource "aws_instance" "web_server" {
#   ami                         = data.aws_ami.ubuntu.id
#   instance_type               = "t3.micro"
#   subnet_id                   = aws_subnet.public_subnets["public_subnet_1"].id
#   associate_public_ip_address = true
#   vpc_security_group_ids = [
#     aws_security_group.ingress-ssh.id,
#     aws_security_group.vpc-web.id
#   ]
#   key_name = aws_key_pair.generated.key_name
#   connection {
#     user        = "ubuntu"
#     private_key = tls_private_key.generated.private_key_pem
#     host        = self.public_ip
#   }

#   # Local provisioner create resources locally
#   # chmod command only for linux and macOS users, Windows users can skip this step
#   # provisioner "local-exec" {
#   #   command = "chmod 600 ${local_file.private_key_pem.filename}"
#   # }

#   /*Do not manage Windows file permissions for a local PEM file inside aws_instance provisioners.
#     That is fragile, host-dependent, and it makes instance creation fail because of a workstation-side command.
#   */

#   # Remote provisioner executes commands on the remote resource after it's created
#   provisioner "remote-exec" {
#     inline = [
#       "sudo rm -rf /tmp",
#       "sudo git clone https://github.com/hashicorp/demo-terraform-101 /tmp",
#       "sudo sh /tmp/assets/setup-web.sh",
#     ]
#   }

#   tags = {
#     Name = local.server_name
#   }

#   lifecycle {
#     ignore_changes = [security_groups]
#   }
# }

# Terraform Resource Block - To Build S3 Bucket
resource "aws_s3_bucket" "my-new-S3-bucket" {
  bucket        = "my-new-tf-test-bucket-${random_id.randomness.hex}"
  force_destroy = true
  tags = {
    Name    = "My S3 Bucket"
    Purpose = "Intro to Resource Blocks Lab"
  }
}

# Terraform Resource Block - To Build Security Group
resource "aws_security_group" "ingress-ssh" {
  name   = "allow-all-ssh"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group - Web Traffic
resource "aws_security_group" "vpc-web" {
  name        = "vpc-web-${terraform.workspace}"
  vpc_id      = aws_vpc.vpc.id
  description = "Web Traffic"
  ingress {
    description = "Allow Port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow Port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow all ip and ports outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Append name to bucket name to ensure uniqueness
resource "random_id" "randomness" {
  byte_length = 4
}

# Create subnet with variables
resource "aws_subnet" "variables-subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.variables_sub_cidr
  availability_zone       = var.variables_sub_az
  map_public_ip_on_launch = var.variables_sub_auto_ip
  tags = {
    Name      = "sub-variables-${var.variables_sub_az}"
    Terraform = "true"
  }
}

# Generate TLS private key
resource "tls_private_key" "generated" {
  algorithm = "RSA"
}

# Save the generated private key to a local file
resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "${path.module}/MyAWSKey.pem"
}

/* Create an AWS Key Pair using the generated public key
Register the public key with AWS to allow SSH access to EC2 instances */
resource "aws_key_pair" "generated" {
  key_name   = "MyAWSKey"
  public_key = tls_private_key.generated.public_key_openssh
  lifecycle {
    ignore_changes = [key_name]
  }
}

# Empty resource block for import pre-existing EC2 instance
# resource "aws_instance" "aws_linux" {
#   ami           = "ami-0c0292c4186d3d1ec"
#   instance_type = "t3.micro"
#   tags = {
#     Name = "Existing Server - Precreated and later imported to terraform configuration"
#   }
# }

# Remove the entire block:
#
# resource "aws_instance" "web" {
# ...
# }
module "server" {
  source    = "./modules/server"
  ami       = data.aws_ami.ubuntu.id
  subnet_id = aws_subnet.public_subnets["public_subnet_1"].id
  vpc_security_group_ids = [
    aws_security_group.ingress-ssh.id,
    aws_security_group.vpc-web.id
  ]
  identity = local.server_name
}

# module "server_subnet_2" {
#   source    = "./modules/server"
#   ami       = data.aws_ami.ubuntu.id
#   subnet_id = aws_subnet.public_subnets["public_subnet_2"].id
#   vpc_security_group_ids = [
#     aws_security_group.ingress-ssh.id,
#     aws_security_group.vpc-web.id
#   ]
#   identity = local.server_name
# }

module "server_subnet_2" {
  source          = "./modules/web_server"
  ami             = data.aws_ami.ubuntu.id
  key_name        = aws_key_pair.generated.key_name
  user            = "ubuntu"
  private_key     = tls_private_key.generated.private_key_pem
  subnet_id       = aws_subnet.public_subnets["public_subnet_2"].id
  security_groups = [aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id]
}

# module "autoscaling" {
#   source  = "terraform-aws-modules/autoscaling/aws"
#   version = "4.9.0"
#   # Autoscaling group
#   name                = "myasg"
#   vpc_zone_identifier = [aws_subnet.private_subnets["private_subnet_1"].id, aws_subnet.private_subnets["private_subnet_2"].id]
#   min_size            = 0
#   max_size            = 1
#   desired_capacity    = 1
#   # Launch template
#   # use_lt        = true
#   # create_lt     = true
#   # image_id      = data.aws_ami.ubuntu.id
#   # instance_type = "t3.micro"
#   tags_as_map = {
#     Name = "Web EC2 Server 2"
#   }
# }

module "autoscaling" {
  source = "github.com/terraform-aws-modules/terraform-aws-autoscaling"
  # Autoscaling group
  name                = "myasg"
  vpc_zone_identifier = [aws_subnet.private_subnets["private_subnet_1"].id, aws_subnet.private_subnets["private_subnet_2"].id]
  min_size            = 0
  max_size            = 1
  desired_capacity    = 1
  # Launch template
  # use_lt        = true
  # create_lt     = true
  # image_id      = data.aws_ami.ubuntu.id
  # instance_type = "t3.micro"
  # tags_as_map = {
  #   Name = "Web EC2 Server 2"
  # }
}
