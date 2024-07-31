## learn-aws-wordpress-ec2
```ruby
alias tf="terraform"; alias tfa="terraform apply --auto-approve"; alias tfd="terraform destroy --auto-approve"; alias tfm="terraform init; terraform fmt; terraform validate; terraform plan"
```
## https://developer.hashicorp.com/terraform/install
Install if running at cloudshell
```ruby
sudo yum install -y yum-utils shadow-utils; sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo; sudo yum -y install terraform; terraform init
```
This setup includes:

The EC2 instance is provisioned with MySQL and is placed in a private subnet for added security. The MySQL root password is set using a Terraform provisioner that runs a series of commands on the instance after it is created.
```bash
terraform apply -var-file="terraform.tfvars.json" --auto-approve -input=false
```
how to - https://docs.aws.amazon.com/codedeploy/latest/userguide/tutorials-wordpress.html

how to use github actions with aws access and secret - https://spacelift.io/blog/github-actions-terraform

https://www.pluralsight.com/resources/blog/cloud/how-to-use-github-actions-to-automate-terraform

how to use github actions with openid and sts temp cred - https://xebia.com/blog/how-to-deploy-terraform-to-aws-with-github-actions-authenticated-with-openid-connect/

how to use aws s3 and dynamodb to do version control of tfstate - https://medium.com/@Vertexwahn/manage-terraform-state-in-a-aws-dce66788ed1
