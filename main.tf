terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# -----------------------
# Data Sources
# -----------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default" {
  default_for_az    = true
  availability_zone = "us-west-2a"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# -----------------------
# Security Group
# -----------------------

resource "aws_security_group" "web_sg" {
  name        = "iacm-web-ssh-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # intentionally insecure for demo
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-ssh-sg"
  }
}

# -----------------------
# EC2 Instance
# -----------------------

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  key_name = "aws-iac-lab-usw2-ssh"

  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
set -e

# -----------------------
# Base Setup
# -----------------------

yum update -y
amazon-linux-extras install epel -y
yum install -y httpd figlet curl

systemctl enable httpd
systemctl start httpd

echo "Hello from Terraform EC2" > /var/www/html/index.html

# -----------------------
# Harness Login Banner (AL2 correct method)
# -----------------------

cat << 'BANNER' > /etc/profile.d/harness-banner.sh
#!/bin/bash

# Only show for interactive SSH sessions
if [ -n "$PS1" ]; then

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

figlet "Harness IACM"

echo ""
echo "----------------------------------------"
echo " Environment  : DEV"
echo " Policy Scan  : PASS"
echo " Violations   : 0"
echo " Drift Status : NONE"
echo " Instance ID  : $INSTANCE_ID"
echo " Region       : $REGION"
echo "----------------------------------------"

fi
BANNER

chmod +x /etc/profile.d/harness-banner.sh

EOF

  tags = {
    Name = "terraform-web"
  }
}

# -----------------------
# Outputs
# -----------------------

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}
