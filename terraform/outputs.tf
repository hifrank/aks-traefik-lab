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

# Application Gateway outputs
output "application_gateway_name" {
  description = "Name of the Application Gateway"
  value       = azurerm_application_gateway.agw.name
}

output "application_gateway_id" {
  description = "ID of the Application Gateway"
  value       = azurerm_application_gateway.agw.id
}

output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.agw_pip.ip_address
}

output "application_gateway_fqdn" {
  description = "FQDN of the Application Gateway"
  value       = azurerm_public_ip.agw_pip.fqdn
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

output "agw_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.agw_subnet.id
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

output "agw_identity_id" {
  description = "ID of the Application Gateway managed identity"
  value       = azurerm_user_assigned_identity.agw_identity.id
}

output "agw_identity_principal_id" {
  description = "Principal ID of the Application Gateway managed identity"
  value       = azurerm_user_assigned_identity.agw_identity.principal_id
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
    public_ip          = azurerm_public_ip.agw_pip.ip_address
    kubeconfig_command = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name}"
  }
}
