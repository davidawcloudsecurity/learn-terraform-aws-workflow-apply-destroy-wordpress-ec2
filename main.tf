provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "public" {
  count = 1
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.public_subnet_cidrs, 0)
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_app" {
  count = 1
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.private_app_subnet_cidrs, 0)
}

resource "aws_subnet" "private_db" {
  count = 1
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.private_db_subnet_cidrs, 0)
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.main.id
  subnet_id = element(aws_subnet.public.*.id, 0)
}

resource "aws_eip" "main" {
  vpc = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id = element(aws_subnet.public.*.id, 0)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

resource "aws_route_table_association" "private_app" {
  subnet_id = element(aws_subnet.private_app.*.id, 0)
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db" {
  subnet_id = element(aws_subnet.private_db.*.id, 0)
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "web" {
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
}

resource "aws_security_group" "app" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  count = var.instance_count
  ami = var.ami_id
  instance_type = var.instance_type
  subnet_id = element(aws_subnet.public.*.id, 0)
  security_groups = [aws_security_group.web.id]
  key_name = var.key_name

  tags = {
    Name = "WebServer-${count.index}"
  }
}

resource "aws_instance" "app" {
  count = var.instance_count
  ami = var.ami_id
  instance_type = var.instance_type
  subnet_id = element(aws_subnet.private_app.*.id, 0)
  security_groups = [aws_security_group.app.id]
  key_name = var.key_name

  tags = {
    Name = "AppServer-${count.index}"
  }
}

resource "aws_db_instance" "default" {
  allocated_storage    = var.rds_allocated_storage
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = var.rds_instance_class
  name                 = var.rds_db_name
  username             = var.rds_username
  password             = var.rds_password
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name = aws_db_subnet_group.main.name
}

resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [element(aws_subnet.private_db.*.id, 0)]
}
