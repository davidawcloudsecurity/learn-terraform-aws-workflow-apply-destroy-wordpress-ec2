## learn-aws-wordpress-ec2
This setup includes:

A VPC

A public subnet for web servers

Two private subnets, one for app servers and one for the database server

An Internet Gateway and NAT Gateway

Security groups for web, app, and database servers

EC2 instances for web and app servers

An RDS instance for the database
```bash
terraform apply -var-file="terraform.tfvars.json"
```

how to - https://docs.aws.amazon.com/codedeploy/latest/userguide/tutorials-wordpress.html
