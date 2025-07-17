# AKS Traefik Lab Makefile
# Provides convenient commands for managing the lab environment

.PHONY: help init plan deploy validate clean destroy status logs

# Default target
help: ## Show this help message
	@echo "AKS Traefik Lab - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make deploy                    # Deploy the complete lab"
	@echo "  make configure-zones LOCATION=southeastasia  # Configure availability zones"
	@echo "  make validate                  # Validate the deployment"
	@echo "  make logs                      # Show application logs"
	@echo "  make destroy                   # Clean up all resources"

# Prerequisites check
check-deps: ## Check if all required tools are installed
	@echo "Checking dependencies..."
	@which az > /dev/null || (echo "❌ Azure CLI not found" && exit 1)
	@which terraform > /dev/null || (echo "❌ Terraform not found" && exit 1)
	@which kubectl > /dev/null || (echo "❌ kubectl not found" && exit 1)
	@which helm > /dev/null || (echo "❌ Helm not found" && exit 1)
	@echo "✅ All dependencies satisfied"

# Terraform operations
init: check-deps ## Initialize Terraform
	@cd terraform && terraform init

plan: init ## Plan the Terraform deployment
	@cd terraform && terraform plan

apply: init ## Apply the Terraform configuration
	@cd terraform && terraform apply

# Complete deployment
deploy: check-deps ## Deploy the complete lab environment
	@./scripts/deploy.sh

deploy-skip-providers: check-deps ## Deploy the lab environment (skip resource provider registration)
	@./scripts/deploy.sh --skip-providers

# Validation and status
validate: ## Validate the deployment
	@./scripts/validate.sh

troubleshoot: ## Run troubleshooting diagnostics
	@./scripts/troubleshoot.sh

status: ## Show cluster and application status
	@echo "=== Cluster Info ==="
	@kubectl cluster-info
	@echo ""
	@echo "=== Nodes ==="
	@kubectl get nodes
	@echo ""
	@echo "=== Traefik Status ==="
	@kubectl get pods,svc -n traefik
	@echo ""
	@echo "=== Sample App Status ==="
	@kubectl get pods,svc -n sample-app
	@echo ""
	@echo "=== Ingress Resources ==="
	@kubectl get ingressroute,middleware -A

# Logs and troubleshooting
logs: ## Show application logs
	@echo "=== Traefik Logs ==="
	@kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=50
	@echo ""
	@echo "=== Sample App Logs ==="
	@kubectl logs -n sample-app -l app=sample-app --tail=20

logs-follow: ## Follow Traefik logs
	@kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f

events: ## Show recent events
	@echo "=== Traefik Events ==="
	@kubectl get events -n traefik --sort-by='.lastTimestamp'
	@echo ""
	@echo "=== Sample App Events ==="
	@kubectl get events -n sample-app --sort-by='.lastTimestamp'

# Port forwarding
dashboard: ## Port-forward to Traefik dashboard
	@echo "Opening Traefik dashboard at http://localhost:8080/dashboard/"
	@kubectl port-forward -n traefik svc/traefik-dashboard 8080:8080

# Configuration management
configure-zones: ## Configure availability zones for the specified location
	@echo "Configuring availability zones for location: $(LOCATION)"
	@case "$(LOCATION)" in \
		"eastus"|"East US"|"eastus2"|"East US 2") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"southeastasia"|"Southeast Asia"|"eastasia"|"East Asia") echo "Using zones: [1, 3]" && zones='["1", "3"]' ;; \
		"westeurope"|"West Europe"|"northeurope"|"North Europe") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"japaneast"|"Japan East"|"japanwest"|"Japan West") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"australiaeast"|"Australia East"|"australiasoutheast"|"Australia Southeast") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"canadacentral"|"Canada Central"|"canadaeast"|"Canada East") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"uksouth"|"UK South"|"ukwest"|"UK West") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"westus2"|"West US 2"|"westus"|"West US") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"centralus"|"Central US"|"southcentralus"|"South Central US") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"francecentral"|"France Central"|"francesouth"|"France South") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"brazilsouth"|"Brazil South") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"southafricanorth"|"South Africa North") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"uaenorth"|"UAE North") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"koreasouth"|"Korea South"|"koreacentral"|"Korea Central") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"switzerlandnorth"|"Switzerland North"|"switzerlandwest"|"Switzerland West") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"germanynorth"|"Germany North"|"germanywestcentral"|"Germany West Central") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		"norwayeast"|"Norway East"|"norwaywest"|"Norway West") echo "Using zones: [1, 2, 3]" && zones='["1", "2", "3"]' ;; \
		*) echo "⚠️  Unknown location: $(LOCATION). Using default zones [1, 3]" && zones='["1", "3"]' ;; \
	esac; \
	if [ -f terraform/terraform.tfvars ]; then \
		if grep -q "availability_zones" terraform/terraform.tfvars; then \
			sed -i '' "s/availability_zones = .*/availability_zones = $$zones/" terraform/terraform.tfvars; \
		else \
			echo "availability_zones = $$zones" >> terraform/terraform.tfvars; \
		fi; \
		echo "✅ Updated terraform/terraform.tfvars with availability_zones = $$zones"; \
	else \
		echo "⚠️  terraform/terraform.tfvars not found. Run 'make dev-setup' first."; \
	fi

get-config: ## Get cluster configuration
	@echo "=== Cluster Configuration ==="
	@kubectl config current-context
	@echo ""
	@echo "=== Traefik Configuration ==="
	@kubectl get configmap traefik-config -n traefik -o yaml

get-creds: ## Get AKS credentials
	@$(eval RESOURCE_GROUP := $(shell cd terraform && terraform output -raw resource_group_name 2>/dev/null || echo "rg-aks-traefik-lab"))
	@$(eval CLUSTER_NAME := $(shell cd terraform && terraform output -raw aks_cluster_name 2>/dev/null || echo "aks-traefik-lab"))
	@az aks get-credentials --resource-group $(RESOURCE_GROUP) --name $(CLUSTER_NAME) --overwrite-existing

# Scaling operations
scale-up: ## Scale Traefik to 3 replicas
	@kubectl scale deployment traefik -n traefik --replicas=3
	@echo "Scaled Traefik to 3 replicas"

scale-down: ## Scale Traefik to 1 replica
	@kubectl scale deployment traefik -n traefik --replicas=1
	@echo "Scaled Traefik to 1 replica"

# Testing
test-connectivity: ## Test application connectivity
	@$(eval TRAEFIK_IP := $(shell kubectl get service traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'))
	@echo "Testing connectivity to Traefik at $(TRAEFIK_IP)"
	@curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "http://$(TRAEFIK_IP)" || echo "Connection failed"

test-https: ## Test HTTPS connectivity
	@$(eval TRAEFIK_IP := $(shell kubectl get service traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'))
	@echo "Testing HTTPS connectivity to Traefik at $(TRAEFIK_IP)"
	@curl -s -k -o /dev/null -w "HTTPS Status: %{http_code}\n" "https://$(TRAEFIK_IP)" || echo "HTTPS connection failed"

# Cleanup operations
clean-pods: ## Delete failed pods
	@kubectl delete pods --field-selector=status.phase=Failed -A

restart-traefik: ## Restart Traefik deployment
	@kubectl rollout restart deployment traefik -n traefik
	@kubectl rollout status deployment traefik -n traefik

# Destruction
destroy: ## Destroy all resources
	@echo "⚠️  This will destroy all resources!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@cd terraform && terraform destroy -auto-approve

# Development helpers
dev-setup: ## Set up development environment
	@echo "Setting up development environment..."
	@cp terraform/terraform.tfvars.example terraform/terraform.tfvars
	@echo "✅ Edit terraform/terraform.tfvars with your values"
	@echo "✅ Run 'make deploy' to deploy the lab"

update-kubeconfig: get-creds ## Update kubeconfig (alias for get-creds)

# Documentation
docs: ## Generate documentation
	@echo "Generating documentation..."
	@terraform-docs markdown table terraform/ > terraform/README.md
	@echo "✅ Documentation generated in terraform/README.md"

# Monitoring helpers
top: ## Show resource usage
	@echo "=== Node Resource Usage ==="
	@kubectl top nodes
	@echo ""
	@echo "=== Pod Resource Usage ==="
	@kubectl top pods -A

describe-traefik: ## Describe Traefik resources
	@echo "=== Traefik Deployment ==="
	@kubectl describe deployment traefik -n traefik
	@echo ""
	@echo "=== Traefik Service ==="
	@kubectl describe service traefik -n traefik
	@echo ""
	@echo "=== Traefik Pods ==="
	@kubectl describe pods -l app.kubernetes.io/name=traefik -n traefik

# Quick commands
quick-status: ## Quick status check
	@echo "🔍 Quick Status Check"
	@echo "Cluster: $(shell kubectl config current-context)"
	@echo "Traefik: $(shell kubectl get pods -n traefik -l app.kubernetes.io/name=traefik --no-headers | wc -l) pods"
	@echo "Sample App: $(shell kubectl get pods -n sample-app -l app=sample-app --no-headers | wc -l) pods"
	@echo "LoadBalancer IP: $(shell kubectl get service traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

# Default values
RESOURCE_GROUP ?= rg-aks-traefik-lab
CLUSTER_NAME ?= aks-traefik-lab
LOCATION ?= eastus
