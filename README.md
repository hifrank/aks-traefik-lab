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

## 🧹 Cleanup

To remove all resources:

```bash
make destroy
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Availability Zone Not Supported Error

**Error**: `The zone(s) '2' for resource 'default' is not supported. The supported zones for location 'southeastasia' are '3,1'`

**Solution**: Different Azure regions support different availability zones. Update your configuration:

```bash
# For Southeast Asia region
make configure-zones LOCATION=southeastasia

# Or manually edit terraform/terraform.tfvars
availability_zones = ["1", "3"]
```

**Common region-specific zones**:
- **East US**: `["1", "2", "3"]`
- **Southeast Asia**: `["1", "3"]` (zone 2 not supported)
- **West Europe**: `["1", "2", "3"]`
- **Japan East**: `["1", "2", "3"]`

#### 2. Resource Provider Not Registered

**Error**: `The subscription is not registered to use namespace 'Microsoft.ContainerService'`

**Solution**: The deployment script automatically registers required providers, but you can also do it manually:

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
```

#### 3. Application Gateway Creation Fails

**Error**: `priority` field is required for request routing rules

**Solution**: This has been fixed in the latest version. Make sure you're using the updated `main.tf` file.

#### 4. Terraform State Lock

**Error**: `Error locking state: Error acquiring the state lock`

**Solution**: 
```bash
cd terraform
terraform force-unlock <LOCK_ID>
```

#### 5. kubectl Connection Issues

**Error**: `Unable to connect to the server`

**Solution**: 
```bash
make get-creds
# or
az aks get-credentials --resource-group <rg-name> --name <cluster-name> --overwrite-existing
```

#### 6. Traefik Dashboard Not Accessible

**Issue**: Cannot access Traefik dashboard

**Solution**: 
```bash
# Check if pods are running
kubectl get pods -n traefik

# Port forward to dashboard
make dashboard
# or
kubectl port-forward -n traefik svc/traefik-dashboard 8080:8080
```

#### 7. SSL Certificate Issues

**Issue**: SSL/TLS certificate errors

**Solution**: 
```bash
# Check certificate status
kubectl get certificate -A

# Check cert-manager logs (if using cert-manager)
kubectl logs -n cert-manager -l app=cert-manager
```

#### 8. Load Balancer IP Not Assigned

**Issue**: External IP shows as `<pending>`

**Solution**: 
```bash
# Check service status
kubectl get svc -n traefik

# Check events
kubectl get events -n traefik --sort-by='.lastTimestamp'

# Verify Azure Load Balancer
az network lb list --resource-group <node-resource-group>
```

### Diagnostic Commands

Use these commands to troubleshoot issues:

```bash
# Run complete diagnostics
make troubleshoot

# Check cluster status
make status

# View logs
make logs

# Check resource usage
make top

# Test connectivity
make test-connectivity
```

### Getting Help

1. Check the [troubleshooting script](./scripts/troubleshoot.sh)
2. Review Azure AKS documentation
3. Check Traefik documentation
4. Review Terraform Azure provider documentation

For specific issues, run:
```bash
./scripts/troubleshoot.sh --verbose
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
