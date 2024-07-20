resource "aws_vpc" "vpc" {
    cidr_block = "172.16.0.0/16"

    tags = {
        Name = "vpc"
    }
}


locals {
  vpc_az =  {
    "2a": {
        "az": "ap-northeast-2a",
        "name": "a",
        "public": "101"
    },
    "2b": {
        "az": "ap-northeast-2b",
        "name": "b",
        "public": "102"
    },
    "2c": {
        "az": "ap-northeast-2c",
        "name": "c",
        "public": "103"
    },
    "2d": {
        "az": "ap-northeast-2d",
        "name": "d",
        "public": "104"
    },
  }
}

resource "aws_subnet" "public_subnets" {
    for_each = local.vpc_az

    vpc_id     = aws_vpc.vpc.id
    cidr_block = "172.16.${each.value.public}.0/24"
    availability_zone = each.value.az
    map_public_ip_on_launch = true
    tags = {
        Name = "public_subnet_${each.value.name}"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id

    tags = {
        Name = "Internet Gateway"
    }
}


resource "aws_default_route_table" "public_rt" {
    default_route_table_id = aws_vpc.vpc.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "public route table"
    }
}

resource "aws_route_table_association" "vpc_rt_association" {
  for_each = aws_subnet.public_subnets

  subnet_id = each.value.id
  route_table_id = aws_default_route_table.public_rt.id
}

resource "aws_default_security_group" "default_sg" {
    vpc_id = aws_vpc.vpc.id

    ingress {
        protocol    = "tcp"
        from_port = 0
        to_port   = 65535
        cidr_blocks = [aws_vpc.vpc.cidr_block]
    }

    ingress {
        protocol    = "tcp"
        from_port = 0
        to_port   = 65535
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        protocol    = "-1"
        from_port   = 0
        to_port     = 0
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "default_sg"
        Description = "default security group"
    }
}