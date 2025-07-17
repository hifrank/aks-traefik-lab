# AKS Traefik Lab - Quick Reference

## 🚀 Quick Start Commands

```bash
# 1. Deploy everything
make deploy

# 2. Validate deployment
make validate

# 3. Check status
make status

# 4. View logs
make logs

# 5. Access dashboard
make dashboard

# 6. Clean up
make destroy
```

## 📋 Prerequisites Checklist

- [ ] Azure CLI installed and logged in
- [ ] Terraform >= 1.5 installed
- [ ] kubectl installed
- [ ] Helm 3 installed
- [ ] Azure subscription with contributor access

## 🔧 Configuration Files

| File | Purpose |
|------|---------|
| `terraform/terraform.tfvars` | Infrastructure configuration |
| `k8s/traefik/01-config.yaml` | Traefik static configuration |
| `helm/traefik-aks/values.yaml` | Helm chart values |

## 🌐 Default URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Traefik Dashboard | `https://traefik.example.com/dashboard/` | admin/password |
| Sample App (Traefik) | `https://sample-app.example.com` | - |
| Sample App (AGIC) | `https://sample-app-agic.example.com` | - |

## 🔍 Troubleshooting Commands

```bash
# Check pod status
kubectl get pods -A

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f

# Check AGIC logs
kubectl logs -n kube-system -l app=ingress-appgw

# Check events
kubectl get events -A --sort-by='.lastTimestamp'

# Port-forward to dashboard
kubectl port-forward -n traefik svc/traefik-dashboard 8080:8080

# Test connectivity
curl -k https://$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

## 📊 Monitoring

```bash
# Resource usage
kubectl top nodes
kubectl top pods -A

# Service endpoints
kubectl get endpoints -A

# Ingress status
kubectl get ingressroute -A
kubectl get ingress -A

# Certificate status
kubectl get secrets -A --field-selector type=kubernetes.io/tls
```

## 🔐 Security

```bash
# Check RBAC
kubectl auth can-i --list --as=system:serviceaccount:traefik:traefik

# Check network policies
kubectl get networkpolicies -A

# Check pod security
kubectl get psp,podsecuritypolicy -A
```

## 🎯 Common Issues & Solutions

### Issue: LoadBalancer IP not assigned
```bash
# Check service status
kubectl describe svc traefik -n traefik

# Check Azure Load Balancer
az network lb list --resource-group MC_*
```

### Issue: Traefik not receiving traffic
```bash
# Check endpoints
kubectl get endpoints traefik -n traefik

# Check service selectors
kubectl get svc traefik -n traefik -o yaml
```

### Issue: TLS certificate issues
```bash
# Check TLS secrets
kubectl get secrets -n traefik

# Check certificate details
kubectl get secret traefik-dashboard-tls -n traefik -o yaml
```

### Issue: Application Gateway not working
```bash
# Check AGIC pod logs
kubectl logs -n kube-system -l app=ingress-appgw

# Check Application Gateway configuration
az network application-gateway show -g <resource-group> -n <agw-name>
```

## 🏗️ Architecture Components

```
┌─────────────────────────────────────────────────────────────────┐
│                     Azure Resources                            │
├─────────────────────────────────────────────────────────────────┤
│ • Resource Group                                                │
│ • Virtual Network (10.0.0.0/16)                               │
│ • AKS Cluster (Azure CNI)                                     │
│ • Application Gateway                                          │
│ • Managed Identities                                          │
│ • Log Analytics Workspace                                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Kubernetes Resources                         │
├─────────────────────────────────────────────────────────────────┤
│ • Traefik Deployment (2 replicas)                             │
│ • Traefik Service (LoadBalancer)                              │
│ • IngressRoutes (CRDs)                                        │
│ • Middlewares (Security, CORS, etc.)                          │
│ • Sample Application                                           │
│ • AGIC (Application Gateway Ingress Controller)               │
└─────────────────────────────────────────────────────────────────┘
```

## 📈 Scaling

```bash
# Scale Traefik
kubectl scale deployment traefik -n traefik --replicas=3

# Scale sample app
kubectl scale deployment sample-app -n sample-app --replicas=5

# Scale AKS nodes
az aks nodepool scale --resource-group <rg> --cluster-name <cluster> --name <nodepool> --node-count 5
```

## 🔄 Updates

```bash
# Update Traefik image
kubectl set image deployment/traefik traefik=traefik:v3.1 -n traefik

# Restart deployment
kubectl rollout restart deployment traefik -n traefik

# Check rollout status
kubectl rollout status deployment traefik -n traefik
```

## 🎛️ Advanced Configuration

### Custom Middleware Example
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: custom-headers
  namespace: traefik
spec:
  headers:
    customRequestHeaders:
      X-Custom-Header: "MyValue"
```

### IngressRoute with Multiple Middlewares
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
      middlewares:
        - name: security-headers
          namespace: traefik
        - name: rate-limit
          namespace: traefik
        - name: cors
          namespace: traefik
      services:
        - name: my-app-service
          port: 80
```

## 🆘 Emergency Procedures

### Disaster Recovery
```bash
# Backup Traefik configuration
kubectl get ingressroute,middleware,tlsoption -A -o yaml > traefik-backup.yaml

# Restore from backup
kubectl apply -f traefik-backup.yaml
```

### Complete Reset
```bash
# Delete all Traefik resources
kubectl delete namespace traefik
kubectl delete ingressclass traefik

# Re-deploy
make deploy
```

## 🔗 Useful Links

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Application Gateway for Containers](https://docs.microsoft.com/en-us/azure/application-gateway/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Run `make validate` for automated checks
3. Review logs with `make logs`
4. Check the GitHub issues page
