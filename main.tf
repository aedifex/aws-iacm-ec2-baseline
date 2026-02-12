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

# --------
# Data
# --------

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

# --------
# Networking
# --------

resource "aws_security_group" "web_sg" {
  name        = "iacm-web-ssh-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # will be flagged by scanners
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

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default" {
  default_for_az    = true
  availability_zone = "us-west-2a"
}

# --------
# EC2
# --------

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  key_name = "aws-iac-lab-usw2-ssh" # must already exist

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              echo "Hello from Terraform EC2" > /var/www/html/index.html

              # -----------------------------
# Low-Key Deployment Reveal
# -----------------------------

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

BOOT_FILE="/etc/motd"

figlet "Harness IACM" > $BOOT_FILE
echo "" >> $BOOT_FILE
echo "----------------------------------------" >> $BOOT_FILE
echo " Environment  : DEV" >> $BOOT_FILE
echo " Policy Scan  : PASS" >> $BOOT_FILE
echo " Violations   : 0" >> $BOOT_FILE
echo " Drift Status : NONE" >> $BOOT_FILE
echo " Instance ID  : $INSTANCE_ID" >> $BOOT_FILE
echo " Region       : $REGION" >> $BOOT_FILE
echo "----------------------------------------" >> $BOOT_FILE
              EOF

  tags = {
    Name = "terraform-web"
  }
}

# --------
# Outputs
# --------

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}
