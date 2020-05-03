provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "di-terraform"
    key    = "vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "di"
  }
}

# Private
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Default"
  }
}

resource "aws_main_route_table_association" "default" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.private.id
}

# Public
resource "aws_subnet" "us_east_1a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"

  tags = {
    Name = "10.0.1.0 - us-east-1a"
  }
}

resource "aws_subnet" "us_east_1b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"

  tags = {
    Name = "10.0.2.0 - us-east-1b"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "MainIG"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "10.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Public"
  }
}

resource "aws_route_table_association" "us_east_1a_to_public" {
  subnet_id      = aws_subnet.us_east_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "us_east_2_to_public" {
  subnet_id      = aws_subnet.us_east_1b.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "web" {
  name        = "Web"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "Web"
  }
}

resource "aws_security_group" "dmz" {
  name        = "DMZ"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 16443
    to_port     = 16443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "DMZ"
  }
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "security_group_web_id" {
  value = aws_security_group.web.id
}

output "security_group_dmz_id" {
  value = aws_security_group.dmz.id
}

output "public_subnet_id" {
  value = aws_subnet.us_east_1a.id
}
