#!/bin/bash

# AKS Traefik Lab - Deployment Script
# This script deploys the complete AKS infrastructure and Traefik configuration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TERRAFORM_DIR="${PROJECT_DIR}/terraform"
K8S_DIR="${PROJECT_DIR}/k8s"
HELM_DIR="${PROJECT_DIR}/helm"

# Default values
RESOURCE_GROUP="rg-aks-traefik-lab"
CLUSTER_NAME="aks-traefik-lab"
LOCATION="eastus"
DOMAIN_SUFFIX="example.com"
SKIP_RESOURCE_PROVIDERS="false"

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

check_dependencies() {
    log "Checking dependencies..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        error "Azure CLI is not installed. Please install it first."
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        error "Terraform is not installed. Please install it first."
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed. Please install it first."
    fi
    
    # Check if Helm is installed
    if ! command -v helm &> /dev/null; then
        error "Helm is not installed. Please install it first."
    fi
    
    # Check Azure CLI login
    if ! az account show &> /dev/null; then
        error "You are not logged in to Azure. Please run 'az login' first."
    fi
    
    log "All dependencies are satisfied."
}

register_resource_providers() {
    log "Pre-registering Azure resource providers..."
    
    # List of required resource providers for AKS and related services
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
    
    for provider in "${providers[@]}"; do
        log "Checking provider: $provider"
        
        # Check if provider is already registered with retry logic
        local status
        local check_retries=3
        local check_count=0
        
        while [[ $check_count -lt $check_retries ]]; do
            status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
            
            if [[ "$status" == "Registered" ]]; then
                log "✅ $provider is already registered"
                break
            elif [[ "$status" == "Registering" ]]; then
                log "🔄 $provider is currently being registered. Waiting..."
                sleep 10
                check_count=$((check_count + 1))
            elif [[ "$status" == "NotRegistered" ]]; then
                log "📝 Registering $provider..."
                
                # Register with retry logic for 409 conflicts
                local reg_retries=3
                local reg_count=0
                local registration_success=false
                
                while [[ $reg_count -lt $reg_retries ]]; do
                    if az provider register --namespace "$provider" 2>/dev/null; then
                        log "✅ Successfully initiated registration for $provider"
                        registration_success=true
                        break
                    else
                        reg_count=$((reg_count + 1))
                        if [[ $reg_count -lt $reg_retries ]]; then
                            warn "⚠️  Registration attempt $reg_count failed for $provider. Retrying in 5 seconds..."
                            sleep 5
                        fi
                    fi
                done
                
                if [[ "$registration_success" == false ]]; then
                    warn "⚠️  Failed to register $provider after $reg_retries attempts. Continuing anyway..."
                fi
                break
            else
                check_count=$((check_count + 1))
                if [[ $check_count -lt $check_retries ]]; then
                    warn "⚠️  Unexpected status '$status' for $provider. Retrying in 5 seconds..."
                    sleep 5
                else
                    warn "⚠️  Could not determine status for $provider. Continuing anyway..."
                fi
            fi
        done
    done
    
    log "Resource provider registration completed!"
    log "Note: Some providers may still be registering in the background. This is normal."
}

validate_terraform_config() {
    log "Validating Terraform configuration..."
    
    cd "${TERRAFORM_DIR}"
    
    # Check if Terraform can validate the configuration
    if terraform validate; then
        log "✅ Terraform configuration is valid"
    else
        error "❌ Terraform configuration validation failed. Please check the configuration files."
    fi
    
    # Check if terraform.tfvars exists and is not empty
    if [[ -f "terraform.tfvars" ]]; then
        if [[ -s "terraform.tfvars" ]]; then
            log "✅ terraform.tfvars file exists and is not empty"
        else
            warn "⚠️  terraform.tfvars file is empty. Using default values."
        fi
    else
        log "📝 terraform.tfvars not found. Will create from example."
    fi
}

deploy_infrastructure() {
    log "Deploying Azure infrastructure with Terraform..."
    
    cd "${TERRAFORM_DIR}"
    
    # Initialize Terraform
    terraform init
    
    # Validate Terraform configuration
    validate_terraform_config
    
    # Create terraform.tfvars if it doesn't exist
    if [[ ! -f "terraform.tfvars" ]]; then
        log "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars
    fi
    
    # Update availability zones based on location
    update_availability_zones
    
    # Plan the deployment
    terraform plan -out=tfplan
    
    # Apply the deployment with retry logic for resource provider conflicts
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        log "Attempting Terraform apply (attempt $((retry_count + 1))/$max_retries)..."
        
        if terraform apply tfplan; then
            log "Terraform apply successful!"
            break
        else
            local exit_code=$?
            retry_count=$((retry_count + 1))
            
            if [[ $retry_count -lt $max_retries ]]; then
                warn "Terraform apply failed (exit code: $exit_code). Retrying in 30 seconds..."
                sleep 30
                
                # Re-run terraform plan before retry
                log "Re-planning deployment..."
                terraform plan -out=tfplan
            else
                error "Terraform apply failed after $max_retries attempts. Exit code: $exit_code. Please check the error above."
            fi
        fi
    done
    
    # Get outputs
    CLUSTER_NAME=$(terraform output -raw aks_cluster_name)
    RESOURCE_GROUP=$(terraform output -raw resource_group_name)
    
    log "Infrastructure deployed successfully!"
    log "Cluster Name: ${CLUSTER_NAME}"
    log "Resource Group: ${RESOURCE_GROUP}"
}

configure_kubectl() {
    log "Configuring kubectl..."
    
    # Get AKS credentials
    az aks get-credentials --resource-group "${RESOURCE_GROUP}" --name "${CLUSTER_NAME}" --overwrite-existing
    
    # Verify connection
    kubectl cluster-info
    
    log "kubectl configured successfully!"
}

deploy_traefik() {
    log "Deploying Traefik..."
    
    # Create namespace
    kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply RBAC
    kubectl apply -f "${K8S_DIR}/traefik/"
    
    # Wait for deployment
    kubectl rollout status deployment/traefik -n traefik --timeout=300s
    
    log "Traefik deployed successfully!"
}

deploy_sample_app() {
    log "Deploying sample application..."
    
    # Create namespace
    kubectl create namespace sample-app --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply sample app
    kubectl apply -f "${K8S_DIR}/sample-app/"
    
    # Wait for deployment
    kubectl rollout status deployment/sample-app -n sample-app --timeout=300s
    
    log "Sample application deployed successfully!"
}

get_access_info() {
    log "Getting access information..."
    
    # Get Application Gateway IP
    local agw_ip
    agw_ip=$(cd "${TERRAFORM_DIR}" && terraform output -raw application_gateway_public_ip)
    
    # Get Traefik service IP
    local traefik_ip
    traefik_ip=$(kubectl get service traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    info "=== Access Information ==="
    info "Application Gateway IP: ${agw_ip}"
    info "Traefik LoadBalancer IP: ${traefik_ip}"
    info ""
    info "To access the applications, add these entries to your /etc/hosts file:"
    info "${agw_ip} sample-app-agic.${DOMAIN_SUFFIX}"
    info "${traefik_ip} sample-app.${DOMAIN_SUFFIX}"
    info "${traefik_ip} traefik.${DOMAIN_SUFFIX}"
    info ""
    info "Applications:"
    info "- Sample App (via AGIC): https://sample-app-agic.${DOMAIN_SUFFIX}"
    info "- Sample App (via Traefik): https://sample-app.${DOMAIN_SUFFIX}"
    info "- Traefik Dashboard: https://traefik.${DOMAIN_SUFFIX}/dashboard/"
    info ""
    info "Traefik Dashboard Login:"
    info "Username: admin"
    info "Password: password"
}

show_monitoring_info() {
    log "Monitoring and troubleshooting commands..."
    
    info "=== Useful Commands ==="
    info "# Check Traefik logs"
    info "kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f"
    info ""
    info "# Check Traefik configuration"
    info "kubectl get ingressroute -A"
    info "kubectl get middleware -A"
    info "kubectl get tlsoption -A"
    info ""
    info "# Check Application Gateway Ingress Controller"
    info "kubectl logs -n kube-system -l app=ingress-appgw"
    info ""
    info "# Check sample app"
    info "kubectl logs -n sample-app -l app=sample-app"
    info ""
    info "# Port forward to Traefik dashboard (if ingress is not working)"
    info "kubectl port-forward -n traefik svc/traefik-dashboard 8080:8080"
    info "# Then access: http://localhost:8080/dashboard/"
}

cleanup() {
    log "Cleaning up resources..."
    
    read -p "Are you sure you want to destroy all resources? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "${TERRAFORM_DIR}"
        terraform destroy -auto-approve
        log "Resources cleaned up successfully!"
    else
        log "Cleanup cancelled."
    fi
}

get_availability_zones() {
    local location="$1"
    
    # Convert to lowercase and remove spaces for easier matching
    local normalized_location=$(echo "$location" | tr '[:upper:]' '[:lower:]' | sed 's/ //g')
    
    case "$normalized_location" in
        "eastus"|"eastus2")
            echo '["1", "2", "3"]'
            ;;
        "southeastasia"|"eastasia")
            echo '["1", "3"]'
            ;;
        "westeurope"|"northeurope")
            echo '["1", "2", "3"]'
            ;;
        "japaneast"|"japanwest")
            echo '["1", "2", "3"]'
            ;;
        "australiaeast"|"australiasoutheast")
            echo '["1", "2", "3"]'
            ;;
        "canadacentral"|"canadaeast")
            echo '["1", "2", "3"]'
            ;;
        "uksouth"|"ukwest")
            echo '["1", "2", "3"]'
            ;;
        "westus2"|"westus")
            echo '["1", "2", "3"]'
            ;;
        "centralus"|"southcentralus")
            echo '["1", "2", "3"]'
            ;;
        "francecentral"|"francesouth")
            echo '["1", "2", "3"]'
            ;;
        "brazilsouth")
            echo '["1", "2", "3"]'
            ;;
        "southafricanorth")
            echo '["1", "2", "3"]'
            ;;
        "uaenorth")
            echo '["1", "2", "3"]'
            ;;
        "koreasouth"|"koreacentral")
            echo '["1", "2", "3"]'
            ;;
        "switzerlandnorth"|"switzerlandwest")
            echo '["1", "2", "3"]'
            ;;
        "germanynorth"|"germanywestcentral")
            echo '["1", "2", "3"]'
            ;;
        "norwayeast"|"norwaywest")
            echo '["1", "2", "3"]'
            ;;
        *)
            warn "Unknown location: $location (normalized: $normalized_location). Using default zones [1, 3]"
            echo '["1", "3"]'
            ;;
    esac
}

update_availability_zones() {
    # Read location from terraform.tfvars if it exists
    local location_from_tfvars
    if [[ -f "${TERRAFORM_DIR}/terraform.tfvars" ]]; then
        location_from_tfvars=$(grep '^location' "${TERRAFORM_DIR}/terraform.tfvars" | cut -d'"' -f2)
        if [[ -n "$location_from_tfvars" ]]; then
            log "Using location from terraform.tfvars: ${location_from_tfvars}"
            local effective_location="$location_from_tfvars"
        else
            log "No location found in terraform.tfvars, using script default: ${LOCATION}"
            local effective_location="$LOCATION"
        fi
    else
        log "terraform.tfvars not found, using script default location: ${LOCATION}"
        local effective_location="$LOCATION"
    fi
    
    log "Updating availability zones for location: ${effective_location}"
    
    local zones
    zones=$(get_availability_zones "$effective_location")
    
    log "Using availability zones: ${zones}"
    
    # Update terraform.tfvars with correct zones
    if [[ -f "${TERRAFORM_DIR}/terraform.tfvars" ]]; then
        # Check if availability_zones is already in the file
        if grep -q "availability_zones" "${TERRAFORM_DIR}/terraform.tfvars"; then
            # Use a temp file approach to avoid sed issues
            local temp_file="${TERRAFORM_DIR}/terraform.tfvars.tmp"
            awk -v zones="$zones" '{
                if ($0 ~ /^availability_zones = /) {
                    print "availability_zones = " zones
                } else {
                    print $0
                }
            }' "${TERRAFORM_DIR}/terraform.tfvars" > "$temp_file"
            mv "$temp_file" "${TERRAFORM_DIR}/terraform.tfvars"
        else
            # Add new line
            echo "availability_zones = ${zones}" >> "${TERRAFORM_DIR}/terraform.tfvars"
        fi
        log "✅ Updated terraform.tfvars with availability_zones = ${zones}"
    else
        warn "terraform.tfvars not found. Will be created from example."
    fi
}

# Main script
main() {
    log "Starting AKS Traefik Lab deployment..."
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --resource-group)
                RESOURCE_GROUP="$2"
                shift 2
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --location)
                LOCATION="$2"
                shift 2
                ;;
            --domain-suffix)
                DOMAIN_SUFFIX="$2"
                shift 2
                ;;
            --skip-providers)
                SKIP_RESOURCE_PROVIDERS="true"
                shift
                ;;
            --cleanup)
                cleanup
                exit 0
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --resource-group RG_NAME    Set resource group name"
                echo "  --cluster-name CLUSTER_NAME Set cluster name"
                echo "  --location LOCATION         Set Azure location"
                echo "  --domain-suffix DOMAIN      Set domain suffix"
                echo "  --skip-providers            Skip Azure resource provider registration"
                echo "  --cleanup                   Destroy all resources"
                echo "  --help                      Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Check dependencies
    check_dependencies
    
    # Register resource providers (unless skipped)
    if [[ "$SKIP_RESOURCE_PROVIDERS" != "true" ]]; then
        register_resource_providers
    else
        log "Skipping resource provider registration as requested"
    fi
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Configure kubectl
    configure_kubectl
    
    # Deploy Traefik
    deploy_traefik
    
    # Deploy sample application
    deploy_sample_app
    
    # Show access information
    get_access_info
    
    # Show monitoring information
    show_monitoring_info
    
    log "Deployment completed successfully!"
    log "You can now access your applications using the information above."
}

# Run main function
main "$@"
