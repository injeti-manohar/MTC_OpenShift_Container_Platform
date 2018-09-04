#!/bin/bash

# Notes:
# ID06102018: Created by ganesh.radhakrishnan@microsoft.com
# ID06272018: Updated script to allow creating OCP VM's in a separate subnet within an existing VNET

set -e

if [ $# -le 0 ]; then
  echo -e "\n\tUsage: provision-vms.sh <NO. of OCP Nodes>"
  echo -e "\tMissing argument : No. of OCP nodes!\n"
  exit 1
fi

# IMPORTANT:  Review and configure the following variables before running this script!!
OCP_RG_NAME="rh-ocp39-rg"
RG_LOCATION="westus"
RG_TAGS="CreatedBy=`whoami`"
KEY_VAULT_NAME="OCP-Key-Vault"
IMAGE_SIZE_MASTER="Standard_B2ms"
IMAGE_SIZE_NODE="Standard_B2ms"
IMAGE_SIZE_INFRA="Standard_B2ms"
VM_IMAGE="RedHat:RHEL:7-RAW:latest"
BASTION_HOST="ocp-bastion"
OCP_MASTER_HOST="ocp-master"
OCP_INFRA_HOST="ocp-infra"
VNET_RG_NAME="rh-ocp39-rg"
VNET_CREATE="Yes"
VNET_NAME="ocp39Vnet"
VNET_ADDR_PREFIX="192.168.0.0/16"
SUBNET_NAME="ocp39Subnet"
SUBNET_ADDR_PREFIX="192.168.122.0/24"
OCP_DOMAIN_SUFFIX="devcls.com"

echo "Provisioning Azure resources for OpenShift CP non-HA cluster..."

# Set the default location for all resources
echo "Setting the default location to $RG_LOCATION ..."
az configure --defaults location=$RG_LOCATION

# Create Azure resource group for OpenShift resources
echo "Creating Azure resource group for OpenShift resources..."
az group create --name $OCP_RG_NAME --location $RG_LOCATION --tags $RG_TAGS

# Create a key vault and store the ssh private key as a secret. This will allow us to retrieve the SSH private key at a later time (if needed).
echo "Creating Azure key vault $KEY_VAULT_NAME ..."
az keyvault create --resource-group $OCP_RG_NAME --name $KEY_VAULT_NAME -l $RG_LOCATION --enabled-for-deployment true
az keyvault secret set --vault-name $KEY_VAULT_NAME -n ocpNodeKey --file ~/.ssh/id_rsa

if [ "$VNET_CREATE" ]; then
	# Create the VNET and Subnet
	if [ $VNET_CREATE = "Yes" ] || [ $VNET_CREATE = "yes" ]
	then
  	  # Create the VNET + Subnet in the same RG as the OCP resources
  	  echo "Creating the VNET and Subnet..."
  	  az network vnet create --resource-group $OCP_RG_NAME --name $VNET_NAME --address-prefix $VNET_ADDR_PREFIX --subnet-name $SUBNET_NAME --subnet-prefix $SUBNET_ADDR_PREFIX
	else
  	  echo "Creating Subnet for VNET $VNET_NAME"
	  az network vnet subnet create --address-prefix $SUBNET_ADDR_PREFIX --name $SUBNET_NAME --resource-group $VNET_RG_NAME --vnet-name $VNET_NAME
	fi
else
	echo "VNET/Subnet will not be created.  These resources must exist in RG=[$VNET_RG_NAME]."
fi

# Create the public ip for the bastion host
echo "Creating the public ip for the bastion host..."
az network public-ip create -g $OCP_RG_NAME --name ocpBastionPublicIP --dns-name $BASTION_HOST --allocation-method static

# Create the public ip for the ocp master host
echo "Creating the public ip for the OCP master host..."
az network public-ip create -g $OCP_RG_NAME --name ocpMasterPublicIP --dns-name $OCP_MASTER_HOST --allocation-method static

# Create the public ip for the ocp infra host
echo "Creating the public ip for the OCP infra host..."
az network public-ip create -g $OCP_RG_NAME --name ocpInfraPublicIP --dns-name $OCP_INFRA_HOST --allocation-method static

# Create the network security group for bastion host
echo "Creating the network security group for bastion host..."
az network nsg create -g $OCP_RG_NAME --name ocpBastionSecurityGroup

# Create the network security group for ocp master
echo "Creating the network security group for ocp master..."
az network nsg create -g $OCP_RG_NAME --name ocpMasterSecurityGroup

# Create the network security group for ocp infra
echo "Creating the network security group for ocp infra. node..."
az network nsg create -g $OCP_RG_NAME --name ocpInfraSecurityGroup

# Create the NSG rule for SSH access for bastion host
echo "Creating the NSG rule for SSH access for bastion host..."
az network nsg rule create -g $OCP_RG_NAME --nsg-name ocpBastionSecurityGroup --name ocpSecurityGroupRuleSSH --protocol tcp --priority 1000 --destination-port-range 22 --access allow

# Create the NSG rule for API access for master node
echo "Creating the NSG rule for API access for master node..."
az network nsg rule create -g $OCP_RG_NAME --nsg-name ocpMasterSecurityGroup --name ocpSecurityGroupRuleAPI --protocol tcp --priority 900 --destination-port-range 443 --access allow
echo "Creating the NSG rule for RHEL Cockpit Web UI access from master node..."
az network nsg rule create -g $OCP_RG_NAME --nsg-name ocpMasterSecurityGroup --name ocpSecurityGroupRuleCP --protocol tcp --priority 1000 --destination-port-range 9090 --access allow

echo "Creating the NSG rule for APP access for infra node..."
az network nsg rule create -g $OCP_RG_NAME --nsg-name ocpInfraSecurityGroup --name ocpSecurityGroupRuleAppSSL --protocol tcp --priority 1000 --destination-port-range 443 --access allow
az network nsg rule create -g $OCP_RG_NAME --nsg-name ocpInfraSecurityGroup --name ocpSecurityGroupRuleApp --protocol tcp --priority 2000 --destination-port-range 80 --access allow

vnetId=$(az resource show -g $VNET_RG_NAME -n $VNET_NAME --resource-type "Microsoft.Network/virtualNetworks" --query id --output tsv)
echo "VNET ID=[$vnetId]"
subnetId="$vnetId/subnets/$SUBNET_NAME"
echo "Subnet ID=[$subnetId]"

# Create the NIC for Bastion host
echo "Creating NIC for Bastion Host..."
az network nic create -g $OCP_RG_NAME --name bastionNIC --subnet $subnetId --public-ip-address ocpBastionPublicIP --network-security-group ocpBastionSecurityGroup

# Create the NIC for OCP master host
echo "Creating NIC for OCP master Host..."
az network nic create -g $OCP_RG_NAME --name masterNIC --subnet $subnetId --public-ip-address ocpMasterPublicIP --network-security-group ocpMasterSecurityGroup

# Create the NIC for OCP infra host
echo "Creating NIC for OCP infra Host..."
az network nic create -g $OCP_RG_NAME --name infraNIC --subnet $subnetId --public-ip-address ocpInfraPublicIP --network-security-group ocpInfraSecurityGroup

# Create the availability set
echo "Creating the availability set..."
az vm availability-set create -g $OCP_RG_NAME --name ocpAvailabilitySet

# Create the Bastion Host VM
echo "Creating the bastion host VM..."
az vm create -g $OCP_RG_NAME --name "$BASTION_HOST.$OCP_DOMAIN_SUFFIX" --location $RG_LOCATION --availability-set ocpAvailabilitySet --nics bastionNIC --image $VM_IMAGE --size $IMAGE_SIZE_MASTER --admin-username ocpuser --ssh-key-value ~/.ssh/id_rsa.pub

# Create the OCP Master VM
echo "Creating the OCP Master VM..."
az vm create -g $OCP_RG_NAME --name "$OCP_MASTER_HOST.$OCP_DOMAIN_SUFFIX" --location $RG_LOCATION --availability-set ocpAvailabilitySet --nics masterNIC --image $VM_IMAGE --size $IMAGE_SIZE_MASTER --admin-username ocpuser --ssh-key-value ~/.ssh/id_rsa.pub

# Create the OCP Infra VM
echo "Creating the OCP Infra VM..."
az vm create -g $OCP_RG_NAME --name "$OCP_INFRA_HOST.$OCP_DOMAIN_SUFFIX" --location $RG_LOCATION --availability-set ocpAvailabilitySet --nics infraNIC --image $VM_IMAGE --size $IMAGE_SIZE_MASTER --admin-username ocpuser --ssh-key-value ~/.ssh/id_rsa.pub

# Create the OCP Node VMs...
echo "OCP node count=[$1]..."
i=1
while [ $i -le $1 ]
do
  echo "Creating OCP Node VM $i..."
  az vm create -g $OCP_RG_NAME --name "ocp-node$i.$OCP_DOMAIN_SUFFIX" --location $RG_LOCATION --subnet $subnetId --availability-set ocpAvailabilitySet --image $VM_IMAGE --size $IMAGE_SIZE_NODE --admin-username ocpuser --ssh-key-value ~/.ssh/id_rsa.pub --public-ip-address ""
  i=$(( $i + 1 ))
done

# Copy the SSH private key to the Bastion host
echo "Copying SSH private key to Bastion host..."
scp ~/.ssh/id_rsa "ocpuser@$BASTION_HOST.$RG_LOCATION.cloudapp.azure.com:/home/ocpuser/.ssh"

echo "All OCP infrastructure resources created OK."
