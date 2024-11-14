# Bastion host

Secure access to data warehouses in pre & production environments is an important devOps aspect. The [redshift data-api](https://docs.aws.amazon.com/redshift/latest/mgmt/data-api.html)
offers great programmatic access without typical database access overhead. It is still the case that clients rely on traditional 
database connectivity, and SSH tunneling remains a popular option.

This module allows secure database access for individual users and a tunneling option for dedicated applications such as
analytical and visualisation tools or external integrations.

For a quick howto on [SSH into ec2 instances over SSM](https://cloudonaut.io/connect-to-your-ec2-instance-using-ssh-the-modern-way/)
Make sure to install the session manager plugin on your machine, and adjust your ssh `~/.ssh/config` as recommended, and
have a cli access ready, ideally via `AWS_*` environment variables or other mechanisms such as [the SSO](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html#sso-configure-profile-auto).

```
# SSH over Session Manager
host i-*
 IdentityFile ~/.ssh/<your-key>
 User ubuntu
 ProxyCommand sh -c "aws ec2-instance-connect send-ssh-public-key --instance-id %h --instance-os-user %r --ssh-public-key 'file://~/.ssh/<your-key>.pub' --availability-zone '$(aws ec2 describe-instances --instance-ids %h --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)' && aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
```
Once the resources have been applied, you can either ssh into the host, or alternatively forward the database host to your localhost.   
```shell
ssh i-<instance-id>
# use psql client
psql -h <host-address> -U admin -d dw -p 5439
# forward the remote redshift port to your local (5439) 
ssh -L 5439:$(aws redshift-serverless  list-workgroups  | jq '.workgroup[0].endpoint.address' --raw-output):5439 $(aws ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId" | jq '.[0][0]' --raw-output)
```