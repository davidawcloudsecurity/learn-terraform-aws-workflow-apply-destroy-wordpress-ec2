terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.region
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "public" {
  count                   = 1
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidrs, 0)
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_app" {
  count      = 1
  vpc_id     = aws_vpc.main.id
  cidr_block = element(var.private_app_subnet_cidrs, 0)
}

resource "aws_subnet" "private_db" {
  count      = 1
  vpc_id     = aws_vpc.main.id
  cidr_block = element(var.private_db_subnet_cidrs, 0)
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.main.id
  subnet_id     = element(aws_subnet.public.*.id, 0)
}

resource "aws_eip" "main" {
  #  domain = "vpc"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = element(aws_subnet.public.*.id, 0)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

resource "aws_route_table_association" "private_app" {
  subnet_id      = element(aws_subnet.private_app.*.id, 0)
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_db" {
  subnet_id      = element(aws_subnet.private_db.*.id, 0)
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
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
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
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ssm_role" {
  name = var.ssm_role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = var.ssm_instance_profile
  role = aws_iam_role.ssm_role.name
}

output "seeds" {
  value = [ aws_instance.web.*.private_ip, aws_instance.app.*.private_ip, aws_instance.db.private_ip ]
}

resource "aws_instance" "web" {
  count                = var.instance_count
  ami                  = var.ami_id
  instance_type        = var.instance_type
  subnet_id            = element(aws_subnet.public.*.id, 0)
  security_groups      = [aws_security_group.web.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  #  key_name = var.key_name

  user_data = <<EOF
#!/bin/bash
# Define the path to the sshd_config file
sshd_config="/etc/ssh/sshd_config"

# Define the string to be replaced
old_string="PasswordAuthentication no"
new_string="PasswordAuthentication yes"

# Check if the file exists
if [ -e "$sshd_config" ]; then
    # Use sed to replace the old string with the new string
    sudo sed -i "s/$old_string/$new_string/" "$sshd_config"

    # Check if the sed command was successful
    if [ $? -eq 0 ]; then
        echo "String replaced successfully."
        # Restart the SSH service to apply the changes
        sudo service ssh restart
    else
        echo "Error replacing string in $sshd_config."
    fi
else
    echo "File $sshd_config not found."
fi

echo "123" | passwd --stdin ec2-user
systemctl restart sshd
# Install Docker
yum update -y
yum install docker -y
systemctl start docker; systemctl enable docker; docker pull nginx:latest; docker run -d --name nginx-dev -p 80:80 nginx:latest;
cat <<\EOF1 >> default.conf
upstream backend {
    server ${aws_instance.app[0].private_ip};
}
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;

    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        #root   /usr/share/nginx/html;
        #index  index.html index.htm;
        proxy_pass http://backend;        
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host $host;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
EOF1
docker cp default.conf nginx-dev:/etc/nginx/conf.d;
docker exec nginx-dev nginx -s reload;
EOF

  tags = {
    Name = "WebServer-${count.index}"
  }
}

resource "aws_instance" "app" {
  count           = var.instance_count
  ami             = var.ami_id
  instance_type   = var.instance_type
  subnet_id       = element(aws_subnet.private_app.*.id, 0)
  security_groups = [aws_security_group.app.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  #  key_name = var.key_name

  user_data = <<EOF
#!/bin/bash
# Define the path to the sshd_config file
sshd_config="/etc/ssh/sshd_config"

# Define the string to be replaced
old_string="PasswordAuthentication no"
new_string="PasswordAuthentication yes"

# Check if the file exists
if [ -e "$sshd_config" ]; then
    # Use sed to replace the old string with the new string
    sudo sed -i "s/$old_string/$new_string/" "$sshd_config"

    # Check if the sed command was successful
    if [ $? -eq 0 ]; then
        echo "String replaced successfully."
        # Restart the SSH service to apply the changes
        sudo service ssh restart
    else
        echo "Error replacing string in $sshd_config."
    fi
else
    echo "File $sshd_config not found."
fi

echo "123" | passwd --stdin ec2-user
systemctl restart sshd
# Install Docker
yum update -y
yum install docker -y
systemctl start docker; systemctl enable docker; docker pull wordpress:latest; docker run -d --name wordpress-dev -p 80:80 wordpress:latest
EOF

  tags = {
    Name = "AppServer-${count.index}"
  }
}

resource "aws_instance" "db" {
  ami             = var.db_ami_id
  instance_type   = var.db_instance_type
  subnet_id       = element(aws_subnet.private_db.*.id, 0)
  security_groups = [aws_security_group.db.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  #  key_name        = var.key_name

  tags = {
    Name = "DBServer"
  }

  user_data = <<EOF
#!/bin/bash
# Define the path to the sshd_config file
sshd_config="/etc/ssh/sshd_config"

# Define the string to be replaced
old_string="PasswordAuthentication no"
new_string="PasswordAuthentication yes"

# Check if the file exists
if [ -e "$sshd_config" ]; then
    # Use sed to replace the old string with the new string
    sudo sed -i "s/$old_string/$new_string/" "$sshd_config"

    # Check if the sed command was successful
    if [ $? -eq 0 ]; then
        echo "String replaced successfully."
        # Restart the SSH service to apply the changes
        sudo service ssh restart
    else
        echo "Error replacing string in $sshd_config."
    fi
else
    echo "File $sshd_config not found."
fi

echo "123" | passwd --stdin ec2-user
systemctl restart sshd

# Install Docker
yum update -y
yum install docker -y
systemctl start docker; systemctl enable docker; docker pull mysql:latest;
docker run --name mysql-container -e MYSQL_ROOT_PASSWORD=yourpassword -e MYSQL_DATABASE${var.db_root_password} -p 3306:3306 -v mysql-data:/var/lib/mysql -d mysql:latest
EOF

  /* Remove this as I am not sure how to run this
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y mysql-server",
      "sudo systemctl start mysqld",
      "sudo systemctl enable mysqld",
      "mysqladmin -u root password '${var.db_root_password}'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_path)
      host        = self.public_ip
    }
  }
  */
}
