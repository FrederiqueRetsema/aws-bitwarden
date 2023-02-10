# aws-bitwarden

This repo contains a CloudFormation template and documentation to deploy a bitwarden server in your AWS environment. 

## Prerequisites
- In your AWS account should be a route53 hosted zone. In this zone both an A-record and an AAAA-record will be created.
- The AWS CLI should be installed
- For Linux/Mac: the bash scripts use jq to parse JSON output of AWS commands
- You need the smtp address and credentials to be able to send mail from bitwarden.

- Change the json file ``AllowTempAccess.json`` and replace the placeholder IP addresses with your own IP address (see f.e. https://whatismyip.com.)
- Change the shell scripts and change the names of your profiles and domain names:
  - I'm using a profile for storing my CloudFormation templates, this profile is called deployment
  - I'm using a development account for creating and testing these scripts, this profile is called development
  - I used my own development environment, so my prefix is just bitwarden. When you develop in an environment where other people should know they can ask you for more information, add your name and use a prefix like yourname-bitwarden.

## CloudFormation
You can use the ``.\Deploy.ps1`` (Windows) or ``.\Deploy.sh`` (Linux) script to deploy the CloudFormation template to your environment. Please change the parameters in this file before running the script.

The CloudFormation template will create an EC2 instance in a new VPC with one public subnet. 
The Virtual Machine uses both IPv4 and IPv6. By default only egress traffic is allowed to ports 80 and 443. You can use scripts to open the ingress ports (see below).

You can only log on to this VM by using SSM: use the AWS EC2 Console to go to the bitwarden virtual machine, click "Connect" and use Session Manager to log on from your browser.

The CloudFormation template will install Docker, Docker Compose and it will download the Bitwarden installation script. 
Though it would be possible to automate the installation of starting Docker Compose, requesting a certificate and entering the bitwarden key automatically, it seems better to do this manually because we are less dependent on the order and the questions that bitwarden asks during the install.

## Manual steps
Look at the documentation of bitwarden: https://bitwarden.com/help/install-on-premise-linux/#install-bitwarden . CloudFormation has done the steps up to and including the download of bitwarden.sh. Before you start the following commands, first get an installation ID and key: https://bitwarden.com/host/ . 

Open the ingress ports of the SecurityGroup for the world, by starting the script ``AllowTempAccessInit.ps1`` (Windows) / ``AllowTempAccessInit.sh`` (Linux/Max). This will open ports 80 and 443 to the world. Don't worry, we need this just for initialization, in a later step we will limit the access to just the administrator(s).

Log on to the Virtual Machine using Systems Manager and execute the following commands:

```
sudo -i
chown bitwarden:bitwarden /opt/bitwarden/bitwarden.sh
su bitwarden -
cd /opt/bitwarden
./bitwarden.sh install
```

You now have to change variables in ``/opt/bitwarden/bwdata/env/global.override.env`` , see https://bitwarden.com/help/install-on-premise-linux/#post-install-configuration . In my case filling in the values for smtp__host, smtp__username and smtp__password and changing the parameter mail__replyToEmail to a valid email address was enough, the rest of the parameters already had values that worked for me. When you changed this file, restart the server:

```
./bitwarden.sh restart
```

When you don't like the idea of exposing the login screen (with option to create a master account) to other people than yourself, go to AWS Step Functions and stop the running step function. You can fill in either or both IPv4 and IPv6 addresses. In my case my IPv6 address keeps changing, so I specified the whole block of IPv6 addresses that my provider allocated for me. Start the AllowTempAccess.ps1 PowerShell script (or use the AllowTempAccess.sh Bash script). The AllowTempAccess script will start the Step Function AllowTemporaryAccessForAdministrators with the input from the Json file. This will open port 80 and 443 for input and 80, 443 and the e-mail port for outgoing traffic. It will revert the changes to the inbound traffic after (by default) 1800 seconds, which is 30 minutes.

Example AllowTempAccess.json file for using just IPv6:

```
{
    "AdminPublicIPv4CIDRs": [
    ],
    "AdminPublicIPv6CIDRs": [
      "2a10:2222:3333::/48"
    ],
    "OpenDurationSeconds": 1800
}
```

Now you can create a new account using https with the DNS name for bitwarden. Have fun!

BTW: when you don't like the idea that someone who gets access to your bitwarden environment can create a new account, then go back to ``/opt/bitwarden/bwdata/env/global.override.env`` and change globalSettings__disableUserRegistration to true. Then restart bitwarden again using:

```
./bitwarden.sh restart
```

Though the link to create a new account is still present and it is possible to enter values for a new account, after pressing the "Create Account" button the action will fail.

You can now add new entries in your vault. Next time you log on, first change the data in AllowTempAccess (if needed), then use ``AllowTempAccess.ps1`` or ``AllowTempAccess.sh`` to open the ingress ports of the security groups for 30 minutes.

## Monitoring
It's nice to know that no-one can reach your bitwarden vault when you are asleep. But you also provided an e-mail address and a mobile number. These are connected to several alarms.

The mobile number is used to notice you (*):
- When someone (you?) changes the security group (this is also done when you use the scripts in this directory). The scripts start a Step Function that will change the ingress port definitions of the security group. You will get two SMSes per e-mail address that you specify in the JSON file: one for port 80 and one for port 443.
- About 5 minutes before the StepFunction will lock the security group.
- When the network adapter of the Bitwarden instance is changed. Here, again, you will be notified twice per IP address in the JSON file.

The email address is used:
- When someone (you?) tries to use Systems Manager to go to the EC2 Instance (f.e. by starting a session or by sending a command to the instance)
- When the virtual machines has more than 80% CPU usage
- When the virtual machines has more than 80% memory usage
- When the root disk of the Bitwarden Virtual Machine is more than 80% used
- When the EBS disk that is attached to the Bitwarden Virtual Machine is more than 80% used

(*) Please mind that there is a soft limit on the costs of SMS traffic per month. This soft limit is by default $1. You can send a service request to increase this limit.

## Operations
- Every night a snapshot is made of the Virtual Machine. The snapshots are stored for 1 month (by default) and removed after that.
- Executions of Step Functions cannot be removed. They will grow to 1000 executions, then the oldest one is removed by AWS.
- Every night a yum update is done and bitwarden will be updated (if possible) as well. This is done using the cron on the virtual machine.
- When you want to make an export of all data in bitwarden, use JSON file type. CSV will NOT contain cards and identities. JSON will. You can import JSON within (an empty version of) bitwarden afterwards. When you import values that are already there then you will have double data in your vault...

## Using a dedicated user for bitwarden
You might want to use a dedicated user for bitwarden. I tried to help a little bit by creating two roles:
- bitwarden-cli-role-policy: use this one when you want to use the command line interface with least privileged access to start the shell scripts in this repository
- bitwarden-cli-cloud-shell-role-policy: use this one when you want to use the shell script from AWS CloudShell (when you don't see this role then update the stack and change the UseCloudShellParameter parameter to True)

When you just need an IAM user to start the step function that adds/removes ingress ports, than you just need the bitwarden-cli-role-policy role. When you also want to change the inbound ports from your mobile phone, read the next paragraph.

### Configure AWS CloudShell
For most use cases you will use one of the apps to access your credentials. But just when you are on holidays... you might want to add a new credential for that new interesting app you just installed. You can (before your holidays, of course) create a new IAM user in AWS, then add __both__ bitwarden roles to that user. Use a browser to log in to the AWS Console with the new user and then create a cloud shell. Use the following commands to download the script and the config file and set it up for use in the AWS app:

```
curl https://raw.githubusercontent.com/FrederiqueRetsema/aws-bitwarden/main/AllowTempAccessInit.json -o AllowTempAccess.json
curl -O https://raw.githubusercontent.com/FrederiqueRetsema/aws-bitwarden/main/AllowTempAccessCloudShell.sh 
chmod 700 ./AllowTempAccessCloudShell.sh
ln -s ./AllowTempAccessCloudShell.sh ./a
```

Then install the AWS app on your phone and use the newly created users credentials to log on to AWS and enter the CloudShell. In the cloud shell you just have to execute the command

```
./a
```

to open your vault. 30 minutes later it will be closed again. I used the generic IP addresses 0.0.0.0/0 and ::/0 for this, it's just for 30 minutes and it saves you the trouble to find out which IP address you use on your mobile phone.

## Costs
The total costs for this application depend on how often you use your vault. The daily costs are $1.10 for EC2 (tax excluded). Please mind the SNS pricing: when you send 7 messages per open/close of the vault and the price per Transactional SMS is $0.1189, then you might have to pay $0,83 per day. During the setup of bitwarden you might consider raising the 30 minutes to 2 or 3 hours (7200 / 108000 seconds).

For details for your region please look at this site: https://aws.amazon.com/sns/sms-pricing/

