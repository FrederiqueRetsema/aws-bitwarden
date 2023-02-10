# Start the AllowTemporaryAccessForAdministrators step function with sensible values
AWSPROFILE="development"
PREFIX="bitwarden"

# Determine the ARN of the Step Function
StateMachineArn=$(aws stepfunctions list-state-machines --profile ${AWSPROFILE} | 
                  jq '.stateMachines[] | select( .name | contains("'${PREFIX}'-allow-temporary-access-for-administrators")).stateMachineArn' |
                  awk -F'"' '{print $2}')
echo $StateMachineArn

# Execute Step Function
aws stepfunctions start-execution --state-machine-arn $StateMachineArn --input file://AllowTempAccessInit.json --profile ${AWSPROFILE}
