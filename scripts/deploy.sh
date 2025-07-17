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
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
K8S_DIR="${SCRIPT_DIR}/k8s"
HELM_DIR="${SCRIPT_DIR}/helm"

# Default values
RESOURCE_GROUP="rg-aks-traefik-lab"
CLUSTER_NAME="aks-traefik-lab"
LOCATION="eastus"
DOMAIN_SUFFIX="example.com"

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

deploy_infrastructure() {
    log "Deploying Azure infrastructure with Terraform..."
    
    cd "${TERRAFORM_DIR}"
    
    # Initialize Terraform
    terraform init
    
    # Create terraform.tfvars if it doesn't exist
    if [[ ! -f "terraform.tfvars" ]]; then
        log "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars
    fi
    
    # Plan the deployment
    terraform plan -out=tfplan
    
    # Apply the deployment
    terraform apply tfplan
    
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
