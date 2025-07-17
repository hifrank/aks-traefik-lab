# General variables
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-aks-traefik-lab"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-traefik-lab"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.29.7"
}

# Default node pool variables
variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "VM size for default node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "min_node_count" {
  description = "Minimum number of nodes in the default node pool"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes in the default node pool"
  type        = number
  default     = 10
}

variable "availability_zones" {
  description = "List of availability zones for the region"
  type        = list(string)
  default     = ["1", "3"] # Default to zones 1 and 3 (compatible with most regions)
}

# Workload node pool variables
variable "workload_node_count" {
  description = "Number of nodes in the workload node pool"
  type        = number
  default     = 2
}

variable "workload_vm_size" {
  description = "VM size for workload node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "workload_min_node_count" {
  description = "Minimum number of nodes in the workload node pool"
  type        = number
  default     = 1
}

variable "workload_max_node_count" {
  description = "Maximum number of nodes in the workload node pool"
  type        = number
  default     = 10
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "lab"
    Project     = "aks-traefik-lab"
    Owner       = "platform-team"
    ManagedBy   = "terraform"
  }
}

# Network variables
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_address_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "agw_subnet_address_prefix" {
  description = "Address prefix for Application Gateway subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# Optional variables for customization
variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pools"
  type        = bool
  default     = true
}

variable "log_analytics_retention_days" {
  description = "Retention days for Log Analytics workspace"
  type        = number
  default     = 30
}

variable "application_gateway_sku" {
  description = "SKU for Application Gateway"
  type        = string
  default     = "Standard_v2"
}

variable "application_gateway_capacity" {
  description = "Capacity for Application Gateway"
  type        = number
  default     = 2
}
