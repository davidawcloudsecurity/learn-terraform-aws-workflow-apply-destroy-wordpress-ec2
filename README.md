## The end goal is to setup a mcq website using Wordpress, mysql and nginx

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
The appropriate iam policy to allow user to deploy this terraform script
```bash
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:PutRolePolicy",
                "iam:GetRole",
                "iam:CreateInstanceProfile",
                "iam:ListRolePolicies",
                "iam:ListAttachedRolePolicies",
                "iam:GetInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:DetachRolePolicy",
                "iam:ListInstanceProfilesForRole",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:DeleteRole",
                "iam:PassRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringNotEquals": {
                    "iam:PolicyArn": [
                        "arn:aws:iam::aws:policy/AdministratorAccess",
                        "arn:aws:iam::aws:policy/PowerUserAccess"
                    ]
                }
            }
        }
    ]
}
```

## How to add salt to sensitive strings
Add this to wp-config
```bash
curl -s https://api.wordpress.org/secret-key/1.1/salt/
define('AUTH_KEY',         '7+b4+`#5ND0@b1bYzoi>b/4 CE4lKtiCndxo!,NGR?~WH~]TTWZ~y$|~>4$iAs`O');
define('SECURE_AUTH_KEY',  '/7OMRsgj.D-Wl4K zM^>Q-sLp>39Vc?pE.l{f_VR1ERFH%`L-&uJ!>Qm:-.c.g@(');
define('LOGGED_IN_KEY',    'vQJ&-/jZ &&f|+NDHThYda5I`lSoCdm=_lOTI7yNN$T^dEzPbVm <Lj~fd}`qnPb');
define('NONCE_KEY',        'u1^4P)H_^TgYZEHIFI5k|)^!nxBXZ3o@R<EU*/Ua-X&(tD`feAYn2*?|$V-C-R-(');
define('AUTH_SALT',        'lz/,!yT&4*ld5%+Nbh/B|/+.ibh5((2Nde[|d)33kL|GxEp#-_cAcL| eVPONita');
define('SECURE_AUTH_SALT', '>I?Ewuo5p+I<=|/x<xZ&}m+rE=|o]L>-XI|v&w>0uH%99HEa$7ZTlaXW%pkT-==+');
define('LOGGED_IN_SALT',   'Bw4%>Gg-0-FPZ $tFvO$I@.A|~E;#|Uc{h}b.Ney3v`V+Pdf-[?WqaBF.2g[!/HB');
define('NONCE_SALT',       'pI3vMc/kPg5 O{t=F~6uptG}OA;x 2^@2`QC$-A]Vwt0BAFkiq^4v]y(;==Nb[37');
```
Script to do this
```bash
#!/bin/bash

# Define the location of the wp-config.php file
WP_CONFIG_PATH="/var/www/html/wp-config.php"

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

# Insert the generated salts into wp-config.php
# Remove old salts if they exist
sed -i '/^define('\''AUTH_KEY'\''/d' "$WP_CONFIG_PATH"
sed -i '/^define('\''SECURE_AUTH_KEY'\''/d' "$WP_CONFIG_PATH"
sed -i '/^define('\''LOGGED_IN_KEY'\''/d' "$WP_CONFIG_PATH"
sed -i '/^define('\''NONCE_KEY'\''/d' "$WP_CONFIG_PATH"
sed -i '/^define('\''AUTH_SALT'\''/d' "$WP_CONFIG_PATH"
sed -i '/^define('\''SECURE_AUTH_SALT'\''/d' "$WP_CONFIG_PATH"
sed -i '/^define('\''LOGGED_IN_SALT'\''/d' "$WP_CONFIG_PATH"
sed -i '/^define('\''NONCE_SALT'\''/d' "$WP_CONFIG_PATH"

# Append the new salts to the wp-config.php file
cat "$TEMP_SALTS_FILE" >> "$WP_CONFIG_PATH"

# Remove the temporary file
rm "$TEMP_SALTS_FILE"

# Notify the user that the script has completed
echo "WordPress secret keys have been updated successfully."

exit 0
```
how to - https://docs.aws.amazon.com/codedeploy/latest/userguide/tutorials-wordpress.html

how to use github actions with aws access and secret - https://spacelift.io/blog/github-actions-terraform

https://www.pluralsight.com/resources/blog/cloud/how-to-use-github-actions-to-automate-terraform

how to use github actions with openid and sts temp cred - https://xebia.com/blog/how-to-deploy-terraform-to-aws-with-github-actions-authenticated-with-openid-connect/

how to use aws s3 and dynamodb to do version control of tfstate - https://medium.com/@Vertexwahn/manage-terraform-state-in-a-aws-dce66788ed1

how to harden git runners - https://blog.gitguardian.com/github-actions-security-cheat-sheet/

how to run github action in git - https://joht.github.io/johtizen/build/2022/01/20/github-actions-push-into-repository.html

how to git push in github action - https://stackoverflow.com/questions/57921401/push-to-origin-from-github-action

how to allow git push - https://stackoverflow.com/questions/72851548/permission-denied-to-github-actionsbot

how to setup nginx/wordpress/mysql - https://www.digitalocean.com/community/tutorials/how-to-install-wordpress-with-docker-compose
