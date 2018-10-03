variable "user_name" {
	description = "User who is provisioning the Azure resources"
}
variable "env_name" {
	description = "Description of the environment for deploying resources"
}
variable "ocp_rg_name" {
	description = "Azure resource group to deploy resources into"
}
variable "ocp_rg_location" {
	description = "Azure resource group location"
}
variable "image_size_master" {
	default = "Standard_B2ms"
	description = "VM image size for OCP Master node"
}
variable "image_size_infra" {
	default = "Standard_B2ms"
	description = "VM image size for OCP Infrastructure nodes"
}
variable "image_size_node" {
	default = "Standard_B2ms"
	description = "VM image size for OCP Application nodes"
}
variable "ocp_bastion_host" {
	description = "Name of the Bastion host used for configuring all nodes with pre-requisite s/w via Ansible"
}
variable "ocp_master_host" {
	description = "Name of the OCP Master node"
}
variable "ocp_infra_host" {
	description = "Name of the OCP Infrastructure node"
}
variable "ocp_vnet_name" {
	description = "Name of the Azure VNET which will be created"
}
variable "vnet_addr_prefix" {
	description = "Address prefix for Azure VNET"
}
variable "ocp_subnet_name" {
	description = "Name of the Subnet to provision within the VNET"
}
variable "subnet_addr_prefix" {
	description = "Subnet Address prefix (range)"
}
variable "ocp_domain_suffix" {
	description = "Domain suffix for the OCP application domain"
}
variable "ocp_app_node_count" {
	default = 1
	description = "Number of OpenShift Application nodes to provision"
}
variable "ssh_key" {
	default = "xyz"
	description = "SSH Public key to be stored on provisioned VMs"
}
