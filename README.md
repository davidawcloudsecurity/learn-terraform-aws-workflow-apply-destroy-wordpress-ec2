## learn-aws-wordpress-ec2
This setup includes:

The EC2 instance is provisioned with MySQL and is placed in a private subnet for added security. The MySQL root password is set using a Terraform provisioner that runs a series of commands on the instance after it is created.
```bash
terraform apply -var-file="terraform.tfvars.json"
```

how to - https://docs.aws.amazon.com/codedeploy/latest/userguide/tutorials-wordpress.html
