# Resource Group outputs
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# AKS Cluster outputs
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "aks_cluster_node_resource_group" {
  description = "Resource group containing AKS cluster nodes"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "aks_cluster_identity_principal_id" {
  description = "Principal ID of the AKS cluster managed identity"
  value       = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

output "aks_cluster_kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# Application Gateway for Containers (ALB) outputs
output "application_load_balancer_name" {
  description = "Name of the Application Load Balancer"
  value       = azurerm_application_load_balancer.main.name
}

output "application_load_balancer_id" {
  description = "ID of the Application Load Balancer"
  value       = azurerm_application_load_balancer.main.id
}

output "application_load_balancer_frontend_id" {
  description = "ID of the Application Load Balancer frontend"
  value       = azurerm_application_load_balancer_frontend.main.id
}

# Network outputs
output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.aks_vnet.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.aks_vnet.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks_subnet.id
}

output "alb_subnet_id" {
  description = "ID of the Application Load Balancer subnet"
  value       = azurerm_subnet.alb_subnet.id
}

# Managed Identity outputs
output "aks_identity_id" {
  description = "ID of the AKS managed identity"
  value       = azurerm_user_assigned_identity.aks_identity.id
}

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS managed identity"
  value       = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Log Analytics outputs
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.aks_logs.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.aks_logs.name
}

# Kubeconfig command
output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}

# Useful connection information
output "connection_info" {
  description = "Useful connection information"
  value = {
    resource_group     = azurerm_resource_group.main.name
    cluster_name       = azurerm_kubernetes_cluster.aks.name
    location           = azurerm_resource_group.main.location
    alb_name           = azurerm_application_load_balancer.main.name
    kubeconfig_command = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name}"
  }
}
