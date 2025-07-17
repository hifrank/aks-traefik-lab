#!/bin/bash

# AKS Traefik Lab - Troubleshooting Script
# This script helps diagnose common deployment issues

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

check_azure_login() {
    log "Checking Azure login status..."
    
    if az account show &> /dev/null; then
        local account_name
        local subscription_id
        account_name=$(az account show --query "user.name" -o tsv)
        subscription_id=$(az account show --query "id" -o tsv)
        
        log "✅ Logged in as: $account_name"
        log "✅ Subscription: $subscription_id"
    else
        error "❌ Not logged in to Azure. Run 'az login' first."
        exit 1
    fi
}

check_resource_providers() {
    log "Checking Azure resource provider status..."
    
    local providers=(
        "Microsoft.ContainerService"
        "Microsoft.Compute"
        "Microsoft.Network"
        "Microsoft.Storage"
        "Microsoft.ManagedIdentity"
        "Microsoft.Authorization"
        "Microsoft.OperationalInsights"
        "Microsoft.Monitor"
        "Microsoft.Insights"
        "Microsoft.KeyVault"
    )
    
    local registered_count=0
    local total_count=${#providers[@]}
    
    for provider in "${providers[@]}"; do
        local status
        status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotFound")
        
        case "$status" in
            "Registered")
                log "✅ $provider: Registered"
                registered_count=$((registered_count + 1))
                ;;
            "Registering")
                warn "🔄 $provider: Currently registering..."
                ;;
            "NotRegistered")
                warn "⚠️  $provider: Not registered"
                ;;
            *)
                error "❌ $provider: Unknown status ($status)"
                ;;
        esac
    done
    
    info "Resource provider summary: $registered_count/$total_count registered"
    
    if [[ $registered_count -lt $total_count ]]; then
        info "To register missing providers, run:"
        info "  ./scripts/deploy.sh --help"
        info "  # or manually register with:"
        for provider in "${providers[@]}"; do
            local status
            status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotFound")
            if [[ "$status" != "Registered" ]]; then
                info "  az provider register --namespace $provider"
            fi
        done
    fi
}

check_azure_quotas() {
    log "Checking Azure resource quotas..."
    
    local location="eastus"
    
    # Check compute quotas
    info "Checking compute quotas in $location..."
    local vm_quota
    vm_quota=$(az vm list-usage --location "$location" --query "[?localName=='Total Regional vCPUs'].currentValue" -o tsv 2>/dev/null || echo "0")
    local vm_limit
    vm_limit=$(az vm list-usage --location "$location" --query "[?localName=='Total Regional vCPUs'].limit" -o tsv 2>/dev/null || echo "0")
    
    if [[ $vm_quota -lt $vm_limit ]]; then
        log "✅ vCPU quota: $vm_quota/$vm_limit available"
    else
        warn "⚠️  vCPU quota: $vm_quota/$vm_limit (quota exhausted)"
    fi
    
    # Check network quotas
    info "Checking network quotas in $location..."
    local network_quota
    network_quota=$(az network list-usages --location "$location" --query "[?localName=='Virtual Networks'].currentValue" -o tsv 2>/dev/null || echo "0")
    local network_limit
    network_limit=$(az network list-usages --location "$location" --query "[?localName=='Virtual Networks'].limit" -o tsv 2>/dev/null || echo "0")
    
    if [[ $network_quota -lt $network_limit ]]; then
        log "✅ Virtual Network quota: $network_quota/$network_limit available"
    else
        warn "⚠️  Virtual Network quota: $network_quota/$network_limit (quota exhausted)"
    fi
}

check_permissions() {
    log "Checking Azure permissions..."
    
    # Check if user has contributor role
    local has_contributor
    has_contributor=$(az role assignment list --assignee "$(az account show --query user.name -o tsv)" --query "[?roleDefinitionName=='Contributor']" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$has_contributor" ]]; then
        log "✅ Has Contributor role"
    else
        warn "⚠️  May not have Contributor role (required for resource creation)"
    fi
    
    # Check specific permissions
    local permissions=(
        "Microsoft.Resources/subscriptions/resourceGroups/write"
        "Microsoft.ContainerService/managedClusters/write"
        "Microsoft.Network/virtualNetworks/write"
        "Microsoft.Network/applicationGateways/write"
        "Microsoft.ManagedIdentity/userAssignedIdentities/write"
    )
    
    info "Checking specific permissions..."
    for permission in "${permissions[@]}"; do
        if az ad sp show --id "$(az account show --query user.name -o tsv)" --query "appRoles[?value=='$permission']" -o tsv &>/dev/null; then
            log "✅ Has permission: $permission"
        else
            warn "⚠️  May not have permission: $permission"
        fi
    done
}

check_terraform_state() {
    log "Checking Terraform state..."
    
    local terraform_dir="../terraform"
    
    if [[ -d "$terraform_dir" ]]; then
        cd "$terraform_dir"
        
        if [[ -f "terraform.tfstate" ]]; then
            local resources
            resources=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources | length' 2>/dev/null || echo "0")
            
            if [[ $resources -gt 0 ]]; then
                log "✅ Terraform state exists with $resources resources"
                
                # Check if AKS cluster exists
                if terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[].type' | grep -q "azurerm_kubernetes_cluster"; then
                    log "✅ AKS cluster found in state"
                else
                    warn "⚠️  No AKS cluster found in state"
                fi
            else
                warn "⚠️  Terraform state is empty"
            fi
        else
            info "ℹ️  No Terraform state file found (this is normal for new deployments)"
        fi
        
        cd - > /dev/null
    else
        error "❌ Terraform directory not found"
    fi
}

check_application_gateway_config() {
    log "Checking Application Gateway for Containers configuration..."
    
    local terraform_dir="../terraform"
    
    if [[ -d "$terraform_dir" ]]; then
        cd "$terraform_dir"
        
        # Check for Application Gateway for Containers configuration
        if [[ -f "main.tf" ]]; then
            log "✅ main.tf found"
            
            # Check if Application Load Balancer is configured
            if grep -q "azurerm_application_load_balancer" main.tf; then
                log "✅ Application Load Balancer (ALB) is configured"
            else
                warn "⚠️  Application Load Balancer (ALB) configuration not found"
            fi
            
            # Check if ALB subnet is configured
            if grep -q "Microsoft.ServiceNetworking/trafficControllers" main.tf; then
                log "✅ ALB subnet delegation is configured"
            else
                warn "⚠️  ALB subnet delegation configuration not found"
            fi
            
            # Check if managed identity is configured
            if grep -q "identity" main.tf; then
                log "✅ Managed identity is configured"
            else
                warn "⚠️  Managed identity configuration not found"
            fi
            
            # Check if ALB frontend is configured
            if grep -q "azurerm_application_load_balancer_frontend" main.tf; then
                log "✅ ALB frontend is configured"
            else
                warn "⚠️  ALB frontend configuration not found"
            fi
        else
            warn "⚠️  main.tf not found in terraform directory"
        fi
        
        cd - > /dev/null
    else
        warn "⚠️  Terraform directory not found"
    fi
    
    # Check Gateway API resources
    log "Checking Gateway API resources..."
    
    if kubectl get gateway -A >/dev/null 2>&1; then
        log "✅ Gateway API resources are available"
        
        # Check if Gateway is configured
        if kubectl get gateway application-gateway-for-containers -n system >/dev/null 2>&1; then
            log "✅ Application Gateway for Containers Gateway is configured"
        else
            warn "⚠️  Application Gateway for Containers Gateway not found"
        fi
        
        # Check HTTPRoute resources
        if kubectl get httproute -A >/dev/null 2>&1; then
            log "✅ HTTPRoute resources are available"
            
            local httproute_count=$(kubectl get httproute -A --no-headers | wc -l)
            log "📊 Found $httproute_count HTTPRoute(s)"
        else
            warn "⚠️  HTTPRoute resources not found"
        fi
    else
        warn "⚠️  Gateway API CRDs not installed"
        info "💡 You may need to install Gateway API CRDs:"
        info "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml"
    fi
}

show_common_solutions() {
    log "Common solutions for deployment issues..."
    
    info "=== Resource Provider 409 Conflicts ==="
    info "If you see 409 conflicts during resource provider registration:"
    info "1. Wait a few minutes and retry"
    info "2. Use: ./scripts/deploy.sh --skip-providers"
    info "3. Manually register providers one by one"
    info ""
    
    info "=== Terraform Apply Failures ==="
    info "If Terraform apply fails:"
    info "1. Check Azure quotas and permissions"
    info "2. Verify resource provider registration"
    info "3. Run: terraform plan to see what's happening"
    info "4. Check for naming conflicts"
    info ""
    
    info "=== Network/Connectivity Issues ==="
    info "If you have network connectivity issues:"
    info "1. Check Azure service health"
    info "2. Verify your location has AKS support"
    info "3. Try a different Azure region"
    info "4. Check corporate firewall/proxy settings"
    info ""
    
    info "=== Permission Issues ==="
    info "If you get permission errors:"
    info "1. Ensure you have Contributor role"
    info "2. Check if subscription has policy restrictions"
    info "3. Contact your Azure administrator"
    info ""
    
    info "=== Emergency Reset ==="
    info "If everything fails:"
    info "1. Run: make destroy (or ./scripts/deploy.sh --cleanup)"
    info "2. Wait for complete cleanup"
    info "3. Start fresh with: make deploy"
}

main() {
    log "Starting AKS Traefik Lab troubleshooting..."
    
    check_azure_login
    check_resource_providers
    check_azure_quotas
    check_permissions
    check_terraform_state
    check_application_gateway_config
    show_common_solutions
    
    log "Troubleshooting completed!"
    log "If issues persist, check the logs and error messages above."
}

# Run main function
main "$@"
