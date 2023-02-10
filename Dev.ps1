$BucketProfileName="deployment"
$BucketName="frpublic2"
$BucketPrefix="Templates"

$AWSProfile="development"
$TemplateName="CloudFormationBitWarden.yml"
$StackName="bitwarden"
$Prefix="bitwarden"

$DNSRecordName="bitwarden"
$DNSDomainName="mydomain.nl."       # Last dot is important for finding the zone with this name in AWS!
$MailServerPort="587"
$AdminEmail="test@retsema.eu"
$AdminMobile="+31682390591"

cfn-lint ${TemplateName}
if ($LASTEXITCODE -ne 0) {
    exit 1
}

aws s3 cp .\CloudFormationBitwarden.yml  s3://${BucketName}/${BucketPrefix}/${TemplateName} --profile ${BucketProfileName}
aws s3api put-object-acl --bucket ${BucketName} --key ${BucketPrefix}/${TemplateName} --acl public-read --profile ${BucketProfileName}

aws cloudformation create-stack --stack-name ${StackName} `
                                --template-url https://${BucketName}.s3.amazonaws.com/${BucketPrefix}/${TemplateName} `
                                --capabilities CAPABILITY_NAMED_IAM  `
                                --parameters ParameterKey=Prefix,ParameterValue="${Prefix}" `
                                             ParameterKey=DNSRecordName,ParameterValue="${DNSRecordName}" `
                                             ParameterKey=DNSDomainName,ParameterValue="${DNSDomainName}" `
                                             ParameterKey=MailServerPort,ParameterValue="${MailServerPort}" `
                                             ParameterKey=AdminEmail,ParameterValue="${AdminEmail}" `
                                             ParameterKey=AdminMobile,ParameterValue="${AdminMobile}" `
                                --profile ${AWSProfile} 
