variable "account_id" {
  type = string
  default = "db4652ee-8937-47b2-952d-3b883fd2cb33"
  description = "Account id of PDS"
}

variable "scaleup" {
  type        = bool
  description = "Scale up the environment"
  default     = false
}

variable "scaledown" {
  type        = bool
  description = "Scale down the environment"
  default     = false
}

variable "scale_count" {
  type        = number
  description = "Scaleup the environment by number of servers"
  default     = 1
}

variable "tenant_id" {
  type = string
  default = "null"
  description = "Tenant id of PDS account"
}

variable "pds_token" {
  type = string
  default = "null"
  description = "Bearer token from PDS account page"
}

#variable "helm_version" {
#  type = string
#  default = "1.10.4"
#  description = "Helm version used during PDS install."
#}

variable "pds_name" {
  type = string
  default = "pds-demo-from-terraform"
  description = "Target Deployment name for cluster in PDS"
}

variable "px_security" {
  type        = string
  default     = "false"
  description = "Enable security for portworx or not"
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "Username to connect baremetals"
}

variable "cp_node_count" {
  type        = number
  default     = 1
  description = "Number of control plane nodes in k8s cluster"
}

variable "kubespray_version" {
  type        = string
  default     = "2.20"
  description = "Version for Kubespray"
}

variable "px_operator_version" {
  type        = string
  default     = "1.10.1"
  description = "Version for Portworx Operator"
}

variable "k8s_version" {
  type        = string
  default     = "v1.23.0"
  description = "Version for K8s"
}

variable "px_stg_version" {
  type        = string
  default     = "2.12.0"
  description = "Version for Portworx Storage Cluster"
}

variable "cluster_name" {
  type        = string
  default     = "px-cluster"
  description = "Name of the portworx cluster"
}

variable "metal_auth_token" {
  type        = string
  description = "Equinix Metal API Key"
}

variable "metal_project_id" {
  type        = string
  default     = "5422f1fc-2147-43d9-9eef-696b50c80adf"
  description = "Equinix Metal Project ID"
}


variable "metal_organization_id" {
  type        = string
  default     = "null"
  description = "Equinix Metal Organization ID"
}

variable "hostname" {
  type        = string
  default     = "pds-baremetal"
  description = "Hostname for the nodes"
}

variable "metro" {
  type        = string
  default     = "da"
  description = "Equinix Metal Metro to deploy into"
}

variable "node_plan" {
  type        = string
  default     = "m3.large.x86" #c3.medium.x86 #m3.large.x86
  description = "Equinix Metal device type to deploy nodes"
}


variable "nodes_count" {
  type        = number
  default     = 4
  description = "Number of baremetal nodes"
}

variable "operating_system" {
  type        = string
  default     = "rhel_8"
  description = "The Operating system of the node"
}

variable "billing_cycle" {
  type        = string
  default     = "hourly"
  description = "How the node will be billed (Not usually changed)"
}


