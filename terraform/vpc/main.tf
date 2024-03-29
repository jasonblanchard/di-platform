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
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "di"
  }
}

# resource "aws_instance" "fck_nat" {
#   instance_type     = "t4g.nano"
#   ami               = "ami-0f57d652281755ea1"
#   source_dest_check = false

#   tags = {
#     Name = "FCK-NAT"
#   }
# }

# Private
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Default"
  }
}

# resource "aws_route" "nat" {
#   route_table_id = aws_route_table.private.id
#   destination_cidr_block = "0.0.0.0/0"
#   network_interface_id = aws_instance.fck_nat.primary_network_interface_id
# }

resource "aws_main_route_table_association" "default" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.private.id
}

# Public
resource "aws_subnet" "us_east_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "10.0.1.0 - us-east-1a"
  }
}

resource "aws_subnet" "us_east_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "10.0.2.0 - us-east-1b"
  }
}

# Private
resource "aws_subnet" "us_east_1a_private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "10.0.3.0 - us-east-1a private"
  }
}

resource "aws_subnet" "us_east_1b_private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "10.0.4.0 - us-east-1b private"
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
    cidr_block = "0.0.0.0/0"
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

resource "aws_route_table_association" "us_east_1b_to_public" {
  subnet_id      = aws_subnet.us_east_1b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "us_east_1a_to_private" {
  subnet_id      = aws_subnet.us_east_1a_private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "us_east_1b_to_private" {
  subnet_id      = aws_subnet.us_east_1b_private.id
  route_table_id = aws_route_table.private.id
}

# Security Groups
resource "aws_security_group" "web" {
  name   = "Web"
  vpc_id = aws_vpc.main.id

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
  name   = "DMZ"
  vpc_id = aws_vpc.main.id

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

# resource "aws_vpc_endpoint" "secretsmanager" {
#   service_name = "com.amazonaws.us-east-1.secretsmanager"
#   vpc_id = aws_vpc.main.id
#   private_dns_enabled = true
#   security_group_ids = [aws_security_group.web.id]
#   subnet_ids = [aws_subnet.us_east_1a.id, aws_subnet.us_east_1b.id]
#   vpc_endpoint_type = "Interface"
# }

# resource "aws_vpc_endpoint" "s3" {
#   service_name = "com.amazonaws.us-east-1.s3"
#   vpc_id = aws_vpc.main.id
#   route_table_ids = [aws_route_table.public.id]
# }

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

output "subnet_us_east_1a_id" {
  value = aws_subnet.us_east_1a.id
}

output "subnet_us_east_1b_id" {
  value = aws_subnet.us_east_1b.id
}
