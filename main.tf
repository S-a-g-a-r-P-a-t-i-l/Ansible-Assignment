terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}


# Find latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create Security Group
resource "aws_security_group" "app_sg" {
  name        = "ansible-app-sg"
  description = "Allow SSH and Node.js application access"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node.js Application"
    from_port   = 3000
    to_port     = 3000
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
    Name = "ansible-app-sg"
  }
}


# Create EC2 Instance
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = "ansible-key"
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  provisioner "local-exec" {
    command = <<-EOT
      printf '[webservers]\nnode-server ansible_host=%s ansible_user=ubuntu ansible_ssh_private_key_file=%s\n' '${self.public_ip}' '${pathexpand("~/.ssh/ansible-key.pem")}' > terraform_inventory.ini

      echo "Waiting for EC2 SSH..."

      until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -i '${pathexpand("~/.ssh/ansible-key.pem")}' ubuntu@${self.public_ip} "echo SSH Ready" 2>/dev/null; do
        sleep 10
      done

      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i terraform_inventory.ini playbook.yml
    EOT
  }

  tags = {
    Name = "terraform-ansible-server"
  }
}


