#!/bin/bash

# AKS Traefik Lab - Validation Script
# This script validates the deployment and provides troubleshooting information

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

check_cluster_connectivity() {
    log "Checking cluster connectivity..."
    
    if kubectl cluster-info &> /dev/null; then
        log "✅ Cluster connectivity: OK"
        kubectl cluster-info
    else
        error "❌ Cannot connect to cluster"
        return 1
    fi
}

check_nodes() {
    log "Checking node status..."
    
    local ready_nodes
    ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready")
    local total_nodes
    total_nodes=$(kubectl get nodes --no-headers | wc -l)
    
    if [[ $ready_nodes -eq $total_nodes ]]; then
        log "✅ All nodes ready: $ready_nodes/$total_nodes"
        kubectl get nodes
    else
        warn "⚠️  Some nodes not ready: $ready_nodes/$total_nodes"
        kubectl get nodes
    fi
}

check_traefik_deployment() {
    log "Checking Traefik deployment..."
    
    # Check if namespace exists
    if kubectl get namespace traefik &> /dev/null; then
        log "✅ Traefik namespace exists"
    else
        error "❌ Traefik namespace not found"
        return 1
    fi
    
    # Check deployment status
    if kubectl get deployment traefik -n traefik &> /dev/null; then
        local ready_replicas
        ready_replicas=$(kubectl get deployment traefik -n traefik -o jsonpath='{.status.readyReplicas}')
        local desired_replicas
        desired_replicas=$(kubectl get deployment traefik -n traefik -o jsonpath='{.spec.replicas}')
        
        if [[ "$ready_replicas" == "$desired_replicas" ]]; then
            log "✅ Traefik deployment ready: $ready_replicas/$desired_replicas"
        else
            warn "⚠️  Traefik deployment not fully ready: $ready_replicas/$desired_replicas"
        fi
        
        kubectl get deployment traefik -n traefik
    else
        error "❌ Traefik deployment not found"
        return 1
    fi
}

check_traefik_service() {
    log "Checking Traefik service..."
    
    if kubectl get service traefik -n traefik &> /dev/null; then
        local external_ip
        external_ip=$(kubectl get service traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        
        if [[ -n "$external_ip" ]]; then
            log "✅ Traefik LoadBalancer IP: $external_ip"
        else
            warn "⚠️  Traefik LoadBalancer IP not yet assigned"
        fi
        
        kubectl get service traefik -n traefik
    else
        error "❌ Traefik service not found"
        return 1
    fi
}

check_sample_app() {
    log "Checking sample application..."
    
    # Check if namespace exists
    if kubectl get namespace sample-app &> /dev/null; then
        log "✅ Sample app namespace exists"
    else
        error "❌ Sample app namespace not found"
        return 1
    fi
    
    # Check deployment status
    if kubectl get deployment sample-app -n sample-app &> /dev/null; then
        local ready_replicas
        ready_replicas=$(kubectl get deployment sample-app -n sample-app -o jsonpath='{.status.readyReplicas}')
        local desired_replicas
        desired_replicas=$(kubectl get deployment sample-app -n sample-app -o jsonpath='{.spec.replicas}')
        
        if [[ "$ready_replicas" == "$desired_replicas" ]]; then
            log "✅ Sample app deployment ready: $ready_replicas/$desired_replicas"
        else
            warn "⚠️  Sample app deployment not fully ready: $ready_replicas/$desired_replicas"
        fi
        
        kubectl get deployment sample-app -n sample-app
    else
        error "❌ Sample app deployment not found"
        return 1
    fi
}

check_ingress_resources() {
    log "Checking Ingress resources..."
    
    # Check IngressRoutes
    local ingress_routes
    ingress_routes=$(kubectl get ingressroute -A --no-headers | wc -l)
    
    if [[ $ingress_routes -gt 0 ]]; then
        log "✅ Found $ingress_routes IngressRoute(s)"
        kubectl get ingressroute -A
    else
        warn "⚠️  No IngressRoutes found"
    fi
    
    # Check traditional Ingress
    local ingresses
    ingresses=$(kubectl get ingress -A --no-headers | wc -l)
    
    if [[ $ingresses -gt 0 ]]; then
        log "✅ Found $ingresses traditional Ingress(es)"
        kubectl get ingress -A
    else
        info "ℹ️  No traditional Ingresses found (this is expected)"
    fi
}

check_middlewares() {
    log "Checking Traefik middlewares..."
    
    local middlewares
    middlewares=$(kubectl get middleware -A --no-headers | wc -l)
    
    if [[ $middlewares -gt 0 ]]; then
        log "✅ Found $middlewares middleware(s)"
        kubectl get middleware -A
    else
        warn "⚠️  No middlewares found"
    fi
}

check_certificates() {
    log "Checking TLS certificates..."
    
    # Check secrets with TLS type
    local tls_secrets
    tls_secrets=$(kubectl get secrets -A --field-selector type=kubernetes.io/tls --no-headers | wc -l)
    
    if [[ $tls_secrets -gt 0 ]]; then
        log "✅ Found $tls_secrets TLS secret(s)"
        kubectl get secrets -A --field-selector type=kubernetes.io/tls
    else
        warn "⚠️  No TLS secrets found"
    fi
}

test_connectivity() {
    log "Testing application connectivity..."
    
    # Get Traefik service IP
    local traefik_ip
    traefik_ip=$(kubectl get service traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [[ -n "$traefik_ip" ]]; then
        info "Testing connectivity to Traefik at $traefik_ip"
        
        # Test HTTP (should redirect to HTTPS)
        if curl -s -o /dev/null -w "%{http_code}" "http://$traefik_ip" | grep -q "301\|302"; then
            log "✅ HTTP redirect to HTTPS working"
        else
            warn "⚠️  HTTP redirect not working as expected"
        fi
        
        # Test HTTPS (self-signed certificate expected)
        if curl -s -k -o /dev/null -w "%{http_code}" "https://$traefik_ip" | grep -q "200\|404"; then
            log "✅ HTTPS connectivity working"
        else
            warn "⚠️  HTTPS connectivity issues"
        fi
    else
        warn "⚠️  Cannot test connectivity - Traefik IP not available"
    fi
}

show_logs() {
    log "Showing recent logs..."
    
    info "=== Traefik Logs (last 20 lines) ==="
    kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=20
    
    info "=== Sample App Logs (last 10 lines) ==="
    kubectl logs -n sample-app -l app=sample-app --tail=10
    
    info "=== AGIC Logs (last 10 lines) ==="
    kubectl logs -n kube-system -l app=ingress-appgw --tail=10 2>/dev/null || warn "AGIC logs not available"
}

show_events() {
    log "Showing recent events..."
    
    info "=== Traefik Namespace Events ==="
    kubectl get events -n traefik --sort-by='.lastTimestamp' | tail -10
    
    info "=== Sample App Namespace Events ==="
    kubectl get events -n sample-app --sort-by='.lastTimestamp' | tail -10
}

show_recommendations() {
    log "Recommendations and next steps..."
    
    info "=== Recommended Actions ==="
    info "1. Update your /etc/hosts file with the LoadBalancer IP"
    info "2. Install cert-manager for automatic TLS certificates"
    info "3. Configure monitoring with Prometheus and Grafana"
    info "4. Set up log aggregation with Fluentd or Fluent Bit"
    info "5. Configure backup and disaster recovery"
    
    info "=== Useful Commands ==="
    info "# Watch Traefik logs"
    info "kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f"
    info ""
    info "# Port-forward to Traefik dashboard"
    info "kubectl port-forward -n traefik svc/traefik-dashboard 8080:8080"
    info ""
    info "# Check Traefik configuration"
    info "kubectl get ingressroute,middleware,tlsoption -A"
    info ""
    info "# Scale Traefik deployment"
    info "kubectl scale deployment traefik -n traefik --replicas=3"
}

main() {
    log "Starting AKS Traefik Lab validation..."
    
    # Run all checks
    check_cluster_connectivity
    check_nodes
    check_traefik_deployment
    check_traefik_service
    check_sample_app
    check_ingress_resources
    check_middlewares
    check_certificates
    test_connectivity
    show_logs
    show_events
    show_recommendations
    
    log "Validation completed!"
}

# Run main function
main "$@"
