# AKS Traefik Lab

A comprehensive lab for deploying and configuring Traefik as an Ingress Controller on Azure Kubernetes Service (AKS) with Azure Application Gateway for Containers (AGIC).

## 🚀 Features

- **Azure Kubernetes Service (AKS)** with Azure CNI networking
- **Traefik v3** as the primary Ingress Controller
- **Azure Application Gateway for Containers (AGIC)** integration
- **Managed Identity** for secure authentication
- **Auto-scaling** node pools with availability zones
- **Monitoring** with Azure Monitor and Log Analytics
- **Security** best practices with RBAC and network policies
- **Sample applications** with IngressRoute examples

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (>= 2.0.0)
- [Terraform](https://www.terraform.io/downloads.html) (>= 1.5.0)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (>= 1.28.0)
- [Helm](https://helm.sh/docs/intro/install/) (>= 3.0.0)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                           Internet                              │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Azure Application Gateway                      │
│                   (Public IP Address)                          │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AKS Cluster                               │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Default Node   │  │  Workload Node  │  │      Traefik    │  │
│  │     Pool        │  │     Pool        │  │   LoadBalancer  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                 Traefik Ingress Controller                  │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │ │
│  │  │ IngressRoute│  │ Middlewares │  │    Sample App       │ │ │
│  │  │   (CRDs)    │  │   (CORS,    │  │   (Nginx + API)     │ │ │
│  │  │             │  │  Security,  │  │                     │ │ │
│  │  │             │  │  Rate Limit)│  │                     │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd aks-traefik-lab
```

### 2. Login to Azure

```bash
az login
az account set --subscription <subscription-id>
```

### 3. Configure Terraform Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your desired values
```

### 4. Deploy Everything

```bash
./scripts/deploy.sh
```

The deployment script will:
1. ✅ Check all dependencies
2. 🏗️ Deploy AKS infrastructure with Terraform
3. ⚙️ Configure kubectl
4. 🔧 Deploy Traefik Ingress Controller
5. 📱 Deploy sample applications
6. 📊 Provide access information

### 5. Access Your Applications

After deployment, add these entries to your `/etc/hosts` file:

```
<APPLICATION_GATEWAY_IP> sample-app-agic.example.com
<TRAEFIK_LOADBALANCER_IP> sample-app.example.com
<TRAEFIK_LOADBALANCER_IP> traefik.example.com
```

Then access:
- **Sample App (via AGIC)**: https://sample-app-agic.example.com
- **Sample App (via Traefik)**: https://sample-app.example.com
- **Traefik Dashboard**: https://traefik.example.com/dashboard/

## 📁 Project Structure

```
aks-traefik-lab/
├── terraform/                     # Terraform configuration
│   ├── main.tf                   # Main AKS and AGIC configuration
│   ├── variables.tf              # Variable definitions
│   ├── outputs.tf                # Output values
│   └── terraform.tfvars.example  # Example variables
├── k8s/                          # Kubernetes manifests
│   ├── traefik/                  # Traefik configuration
│   │   ├── 00-rbac.yaml         # RBAC permissions
│   │   ├── 01-config.yaml       # Traefik configuration
│   │   ├── 02-deployment.yaml   # Traefik deployment
│   │   ├── 03-service.yaml      # Traefik services
│   │   ├── 04-ingress.yaml      # Dashboard ingress
│   │   └── 05-middlewares.yaml  # Common middlewares
│   └── sample-app/              # Sample application
│       ├── sample-app.yaml      # Application deployment
│       └── ingress-route.yaml   # IngressRoute examples
├── helm/                        # Helm charts
│   └── traefik-aks/            # Traefik Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── scripts/                    # Deployment scripts
    └── deploy.sh              # Main deployment script
```

## 🔧 Configuration

### Terraform Variables

Key variables you can customize in `terraform/terraform.tfvars`:

```hcl
# Basic configuration
resource_group_name = "rg-aks-traefik-lab"
location           = "East US"
cluster_name       = "aks-traefik-lab"
kubernetes_version = "1.28.5"

# Node pool configuration
node_count     = 2
vm_size        = "Standard_D2s_v3"
min_node_count = 1
max_node_count = 5

# Workload node pool
workload_node_count     = 2
workload_vm_size        = "Standard_D4s_v3"
workload_min_node_count = 1
workload_max_node_count = 10

# Tags
tags = {
  Environment = "lab"
  Project     = "aks-traefik-lab"
  Owner       = "platform-team"
}
```

### Traefik Configuration

Traefik is configured with:
- **TLS termination** with automatic HTTPS redirect
- **Dashboard** with basic authentication
- **Metrics** for Prometheus monitoring
- **Middlewares** for security, CORS, rate limiting
- **Load balancing** across multiple replicas

## 🛠️ Manual Deployment

If you prefer to deploy components manually:

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 2. Configure kubectl

```bash
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

### 3. Deploy Traefik

```bash
kubectl apply -f k8s/traefik/
```

### 4. Deploy Sample App

```bash
kubectl apply -f k8s/sample-app/
```

## 📊 Monitoring and Troubleshooting

### Useful Commands

```bash
# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f

# Check Traefik configuration
kubectl get ingressroute -A
kubectl get middleware -A
kubectl get tlsoption -A

# Check Application Gateway Ingress Controller
kubectl logs -n kube-system -l app=ingress-appgw

# Check sample app
kubectl logs -n sample-app -l app=sample-app

# Port forward to Traefik dashboard
kubectl port-forward -n traefik svc/traefik-dashboard 8080:8080
```

### Dashboard Access

If the ingress is not working, you can access the Traefik dashboard via port-forward:

```bash
kubectl port-forward -n traefik svc/traefik-dashboard 8080:8080
```

Then visit: http://localhost:8080/dashboard/

### Metrics

Traefik metrics are available at:
- **Metrics endpoint**: `http://traefik-service:8080/metrics`
- **Prometheus scraping**: Enabled with annotations

## 🔧 Troubleshooting

### Resource Provider 409 Conflicts

The error you encountered is a common Azure issue where multiple operations try to register the same resource providers simultaneously. Here are the solutions:

#### Option 1: Use the improved deployment script (recommended)
The deployment script now includes retry logic and better error handling:

```bash
# The script will automatically retry on conflicts
make deploy
```

#### Option 2: Skip resource provider registration
If you continue to see conflicts, you can skip the resource provider registration:

```bash
# Skip resource provider registration
make deploy-skip-providers
# or
./scripts/deploy.sh --skip-providers
```

#### Option 3: Run troubleshooting diagnostics
Use the troubleshooting script to diagnose issues:

```bash
make troubleshoot
# or
./scripts/troubleshoot.sh
```

### Common Solutions

1. **Wait and retry**: Resource provider conflicts are often temporary
2. **Check quotas**: Ensure you have sufficient Azure quotas
3. **Verify permissions**: Confirm you have Contributor role
4. **Try different region**: Some regions may have capacity issues

### Manual Resource Provider Registration

If needed, you can manually register the required providers:

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.ManagedIdentity
```

## 🔐 Security Features

- **Managed Identity**: AKS uses managed identity for Azure resource access
- **RBAC**: Role-based access control for all components
- **Network Security**: Azure CNI with network policies
- **TLS**: Automatic HTTPS redirect and secure TLS configuration
- **Security Headers**: Comprehensive security headers via middleware
- **Rate Limiting**: Request rate limiting to prevent abuse

## 🌟 Advanced Features

### Custom Middlewares

The lab includes several pre-configured middlewares:

- **Security Headers**: XSS protection, HSTS, frame options
- **CORS**: Cross-origin resource sharing configuration
- **Rate Limiting**: Request throttling
- **Retry**: Automatic retry on failures
- **Circuit Breaker**: Failure detection and recovery
- **Compression**: Response compression

### IngressRoute Examples

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`myapp.example.com`)
      kind: Rule
      services:
        - name: my-app-service
          port: 80
      middlewares:
        - name: security-headers
          namespace: traefik
        - name: rate-limit
          namespace: traefik
  tls:
    - secretName: my-app-tls
```

## 🧹 Cleanup

To remove all resources:

```bash
./scripts/deploy.sh --cleanup
```

Or manually:

```bash
cd terraform
terraform destroy
```

## 📚 Additional Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Azure Application Gateway for Containers](https://docs.microsoft.com/en-us/azure/application-gateway/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues or have questions:

1. Check the [troubleshooting section](#-monitoring-and-troubleshooting)
2. Review the [useful commands](#useful-commands)
3. Check the logs using the provided commands
4. Open an issue in the repository

---

**Happy Kubernetes Ingress with Traefik!** 🚀
