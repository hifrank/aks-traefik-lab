#!/bin/bash

# Gateway API Validation Script for AKS Traefik Lab

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_gateway_api_crds() {
    log "Checking Gateway API CRDs..."
    
    local crds=(
        "gateways.gateway.networking.k8s.io"
        "httproutes.gateway.networking.k8s.io"
        "gatewayclasses.gateway.networking.k8s.io"
    )
    
    for crd in "${crds[@]}"; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            success "✅ CRD $crd is installed"
        else
            error "❌ CRD $crd is not installed"
            return 1
        fi
    done
}

check_gateway_resources() {
    log "Checking Gateway API resources..."
    
    # Check Gateway
    if kubectl get gateway application-gateway-for-containers -n system >/dev/null 2>&1; then
        success "✅ Gateway 'application-gateway-for-containers' exists"
        
        # Check Gateway status
        local gateway_status=$(kubectl get gateway application-gateway-for-containers -n system -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}')
        if [[ "$gateway_status" == "True" ]]; then
            success "✅ Gateway is accepted"
        else
            warn "⚠️  Gateway status: $gateway_status"
        fi
    else
        error "❌ Gateway 'application-gateway-for-containers' not found"
        return 1
    fi
    
    # Check HTTPRoutes
    local httproute_count=$(kubectl get httproute -A --no-headers | wc -l)
    if [[ $httproute_count -gt 0 ]]; then
        success "✅ Found $httproute_count HTTPRoute(s)"
        
        # List HTTPRoutes
        log "HTTPRoutes:"
        kubectl get httproute -A -o custom-columns="NAME:.metadata.name,NAMESPACE:.metadata.namespace,HOSTNAMES:.spec.hostnames[*]"
    else
        warn "⚠️  No HTTPRoutes found"
    fi
}

check_alb_resources() {
    log "Checking Application Gateway for Containers (ALB) resources..."
    
    # Get resource group and ALB name from Terraform
    local terraform_dir="../terraform"
    if [[ -d "$terraform_dir" ]]; then
        cd "$terraform_dir"
        
        if terraform output >/dev/null 2>&1; then
            local resource_group=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
            local alb_name=$(terraform output -raw application_load_balancer_name 2>/dev/null || echo "")
            
            if [[ -n "$resource_group" && -n "$alb_name" ]]; then
                success "✅ ALB '$alb_name' found in resource group '$resource_group'"
                
                # Check ALB status
                if az network application-gateway list --resource-group "$resource_group" --query "[?name=='$alb_name']" >/dev/null 2>&1; then
                    success "✅ ALB is provisioned in Azure"
                else
                    error "❌ ALB not found in Azure"
                fi
            else
                warn "⚠️  Could not get ALB information from Terraform outputs"
            fi
        else
            warn "⚠️  Terraform outputs not available"
        fi
        
        cd - >/dev/null
    else
        warn "⚠️  Terraform directory not found"
    fi
}

check_traefik_integration() {
    log "Checking Traefik integration..."
    
    # Check Traefik service
    if kubectl get service traefik -n traefik >/dev/null 2>&1; then
        success "✅ Traefik service exists"
        
        # Check if service is internal
        local is_internal=$(kubectl get service traefik -n traefik -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-internal}')
        if [[ "$is_internal" == "true" ]]; then
            success "✅ Traefik service is configured as internal LoadBalancer"
        else
            warn "⚠️  Traefik service is not configured as internal LoadBalancer"
        fi
        
        # Check service IP
        local service_ip=$(kubectl get service traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [[ -n "$service_ip" ]]; then
            success "✅ Traefik service has IP: $service_ip"
        else
            warn "⚠️  Traefik service IP is pending"
        fi
    else
        error "❌ Traefik service not found"
        return 1
    fi
    
    # Check Traefik pods
    local traefik_pods=$(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik --no-headers | wc -l)
    if [[ $traefik_pods -gt 0 ]]; then
        success "✅ Found $traefik_pods Traefik pod(s)"
        
        # Check pod status
        local running_pods=$(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik --no-headers | grep Running | wc -l)
        if [[ $running_pods -eq $traefik_pods ]]; then
            success "✅ All Traefik pods are running"
        else
            warn "⚠️  Only $running_pods/$traefik_pods Traefik pods are running"
        fi
    else
        error "❌ No Traefik pods found"
        return 1
    fi
}

check_sample_app() {
    log "Checking sample application..."
    
    # Check sample app deployment
    if kubectl get deployment sample-app -n sample-app >/dev/null 2>&1; then
        success "✅ Sample app deployment exists"
        
        # Check deployment status
        local ready_replicas=$(kubectl get deployment sample-app -n sample-app -o jsonpath='{.status.readyReplicas}')
        local desired_replicas=$(kubectl get deployment sample-app -n sample-app -o jsonpath='{.spec.replicas}')
        
        if [[ "$ready_replicas" == "$desired_replicas" ]]; then
            success "✅ Sample app deployment is ready ($ready_replicas/$desired_replicas)"
        else
            warn "⚠️  Sample app deployment: $ready_replicas/$desired_replicas replicas ready"
        fi
    else
        error "❌ Sample app deployment not found"
        return 1
    fi
    
    # Check sample app service
    if kubectl get service sample-app-service -n sample-app >/dev/null 2>&1; then
        success "✅ Sample app service exists"
    else
        error "❌ Sample app service not found"
        return 1
    fi
}

main() {
    log "Starting Gateway API validation..."
    echo ""
    
    local exit_code=0
    
    # Run checks
    check_gateway_api_crds || exit_code=1
    echo ""
    
    check_gateway_resources || exit_code=1
    echo ""
    
    check_alb_resources || exit_code=1
    echo ""
    
    check_traefik_integration || exit_code=1
    echo ""
    
    check_sample_app || exit_code=1
    echo ""
    
    if [[ $exit_code -eq 0 ]]; then
        success "🎉 All Gateway API validations passed!"
        log ""
        log "Next steps:"
        log "1. Get the ALB frontend IP: kubectl get gateway application-gateway-for-containers -n system -o jsonpath='{.status.addresses[0].value}'"
        log "2. Add DNS entries to /etc/hosts:"
        log "   <ALB_IP> sample-app.example.com"
        log "   <ALB_IP> traefik.example.com"
        log "3. Test access:"
        log "   curl -k https://sample-app.example.com"
        log "   curl -k https://traefik.example.com/dashboard/"
    else
        error "❌ Some Gateway API validations failed"
        log ""
        log "Troubleshooting:"
        log "- Check Gateway API CRDs: kubectl get crd | grep gateway"
        log "- Check Gateway status: kubectl describe gateway application-gateway-for-containers -n system"
        log "- Check HTTPRoute status: kubectl get httproute -A"
        log "- Check Traefik logs: kubectl logs -n traefik -l app.kubernetes.io/name=traefik"
    fi
    
    exit $exit_code
}

main "$@"
