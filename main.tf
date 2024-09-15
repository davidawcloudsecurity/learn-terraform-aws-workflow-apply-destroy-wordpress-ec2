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
cat <<EOF2 > 50x.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Beautiful Loading Page</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            height: 100%;
            display: flex;
            justify-content: center;
            align-items: center;
            background: linear-gradient(45deg, #ff9a9e, #fad0c4, #ffecd2);
            font-family: Arial, sans-serif;
            overflow: hidden;
        }

        .loader-container {
            text-align: center;
        }

        .loader {
            width: 100px;
            height: 100px;
            border: 5px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top-color: #ffffff;
            animation: spin 1s ease-in-out infinite;
        }

        @keyframes spin {
            to { transform: rotate(360deg); }
        }

        .loading-text {
            margin-top: 20px;
            color: white;
            font-size: 24px;
            animation: pulse 1.5s ease-in-out infinite;
        }

        @keyframes pulse {
            0% { opacity: 0.6; }
            50% { opacity: 1; }
            100% { opacity: 0.6; }
        }
    </style>
</head>
<body>
    <div class="loader-container">
        <div class="loader"></div>
        <p class="loading-text">Loading...</p>
    </div>

    <script>
        // Simulating a loading process
        setTimeout(() => {
            document.querySelector('.loading-text').textContent = 'Almost there...';
        }, 3000);

        setTimeout(() => {
            document.querySelector('.loading-text').textContent = 'Ready!';
            document.querySelector('.loader').style.borderTopColor = '#00ff00';
        }, 5000);
    </script>
</body>
</html>
EOF2
docker cp 50x.html nginx-dev:/usr/share/nginx/html;
docker cp default.conf nginx-dev:/etc/nginx/conf.d;
docker exec nginx-dev nginx -s reload;
EOF

  tags = {
    Name = "WebServer-${count.index}"
  }
  depends_on = [
    aws_internet_gateway.main,
    aws_nat_gateway.main,
  ]
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

# Sleep to ensure the container is fully up
sleep 30

# Define variables for database connection
DB_NAME="wordpress_db"
DB_USER="root"
DB_PASSWORD="wp_password"
DB_HOST="${aws_instance.db.private_ip}"
WP_HOME="http://localhost"
WP_SITEURL="http://localhost"

# Create wp-config.php dynamically on the host
cat <<EOF2 > /tmp/wp-config.php
<?php
define('DB_NAME', '${var.db_name}');
define('DB_USER', '$DB_USER');
define('DB_PASSWORD', '${var.db_root_password}');
define('DB_HOST', '$DB_HOST');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

define( 'AUTH_KEY',         'put your unique phrase here' );
define( 'SECURE_AUTH_KEY',  'put your unique phrase here' );
define( 'LOGGED_IN_KEY',    'put your unique phrase here' );
define( 'NONCE_KEY',        'put your unique phrase here' );
define( 'AUTH_SALT',        'put your unique phrase here' );
define( 'SECURE_AUTH_SALT', 'put your unique phrase here' );
define( 'LOGGED_IN_SALT',   'put your unique phrase here' );
define( 'NONCE_SALT',       'put your unique phrase here' );

\$table_prefix  = 'wp_';

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
    define('ABSPATH', '/var/www/html/');
require_once(ABSPATH . 'wp-settings.php');
EOF2

# add salt to wp-config.php
cat <<EOF3 > change_salt
#!/bin/bash

# Define the location of the wp-config.php file
WP_CONFIG_PATH="/tmp/wp-config.php"

# Define a temporary file to store the generated salts
TEMP_SALTS_FILE="/tmp/wordpress_salts.txt"

# Fetch the salts from the WordPress API and save them to the temporary file
curl -s https://api.wordpress.org/secret-key/1.1/salt/ > "$TEMP_SALTS_FILE"

# Check if the temporary file was created successfully
if [[ ! -f "$TEMP_SALTS_FILE" ]]; then
    echo "Error: Unable to fetch secret keys from WordPress API."
    exit 1
fi

# Backup the original wp-config.php file
cp "$WP_CONFIG_PATH" "$WP_CONFIG_PATH.bak"

# Check if the backup was created successfully
if [[ ! -f "$WP_CONFIG_PATH.bak" ]]; then
    echo "Error: Unable to create backup of wp-config.php."
    exit 1
fi

# Replace the existing salt definitions with the new ones
sed -i '/AUTH_KEY/,/NONCE_SALT/ {
    /AUTH_KEY/r '"$TEMP_SALTS_FILE"'
    /AUTH_KEY/,/NONCE_SALT/d
}' "$WP_CONFIG_PATH"

# Remove the temporary file
rm "$TEMP_SALTS_FILE"

# Notify the user that the script has completed
echo "WordPress secret keys have been updated successfully."

exit 0
EOF3
chmod 700 change_salt; ./change_salt

cat <<EOF4 > install_wp
#!/bin/bash

# Define variables
WP_INSTALL_URL="http://localhost/wp-admin/install.php"
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD="admin_password"
WP_ADMIN_EMAIL="admin@example.com"
WP_SITE_TITLE="My WordPress Site"


# Automate WordPress installation
echo "Starting WordPress installation..."

# Use curl to send the necessary POST request to complete the installation
curl -X POST "$WP_INSTALL_URL" \
    --data "weblog_title=$WP_SITE_TITLE" \
    --data "user_name=$WP_ADMIN_USER" \
    --data "pass1=$WP_ADMIN_PASSWORD" \
    --data "pass2=$WP_ADMIN_PASSWORD" \
    --data "admin_email=$WP_ADMIN_EMAIL" \
    --data "blog_public=1" \
    --data "submit=Install+WordPress" \
    --cookie-jar /tmp/wp_cookie_jar

# Check if installation was successful
if curl -sI "$WP_INSTALL_URL" | grep -q "200 OK"; then
    echo "WordPress installation completed successfully."
else
    echo "Error: WordPress installation failed."
    exit 1
fi

# Clean up
rm /tmp/wp_cookie_jar

exit 0
EOF4
chmod 700 install_wp; ./install_wp

# Copy wp-config.php into the running WordPress container
docker cp /tmp/wp-config.php wordpress-dev:/var/www/html/wp-config.php

# Restart the WordPress container to apply changes
docker restart wordpress-dev

EOF

  tags = {
    Name = "AppServer-${count.index}"
  }
  depends_on = [
    aws_internet_gateway.main,
    aws_nat_gateway.main
  ]
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
  depends_on = [
    aws_internet_gateway.main,
    aws_nat_gateway.main
  ]
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
docker run --name mysql-container -e MYSQL_ROOT_PASSWORD=${var.db_root_password} -e MYSQL_DATABASE=${var.db_name} -p 3306:3306 -v mysql-data:/var/lib/mysql -d mysql:latest
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
