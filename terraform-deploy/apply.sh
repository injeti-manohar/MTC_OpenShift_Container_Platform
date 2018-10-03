#!/bin/bash
echo "************* Assigning Azure credentials to env. variables ..."
export ARM_CLIENT_ID=$1
export ARM_CLIENT_SECRET=$2
export ARM_SUBSCRIPTION_ID=$3
export ARM_TENANT_ID=$4
export ARM_ACCESS_KEY=$5
echo "SSH_PUBLIC_KEY=$6"

echo "Current working directory => $PWD"
echo "Dir list => "
ls -l

echo "Executing Terraform Apply ..."
terraform apply -auto-approve -var ssh_key="$6"
if [ $? -ne 0 ]; then
	echo "Terraform Apply failed!"
	exit 1 # terminate and indicate error
fi
echo "Success"
