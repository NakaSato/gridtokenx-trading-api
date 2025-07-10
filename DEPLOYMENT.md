# Energy Trading API - Docker & Kubernetes Deployment

This document describes how to build and deploy the Energy Trading API using Docker and Kubernetes.

## 🐳 Docker Setup

### Prerequisites
- Docker installed and running
- Rust toolchain (for local development)

### Building the Docker Image

```bash
# Build the Docker image
docker build -t energy-trading-api:latest .

# Run the container locally
docker run -p 3000:3000 energy-trading-api:latest
```bash

### Docker Image Features
- **Multi-stage build**: Reduces final image size
- **Non-root user**: Runs with user ID 1000 for security
- **Health checks**: Built-in health check endpoint
- **Optimized layers**: Dependencies cached separately from source code

## ☸️ Kubernetes Deployment

### Prerequisites
- Kubernetes cluster (local or cloud)
- kubectl configured to access your cluster
- Container registry (optional, for production)

### Quick Start

1. **Deploy everything at once:**
   ```bash
   ./deploy.sh
   ```

2. **Or deploy step by step:**
   ```bash
   # Build and push image
   ./deploy.sh build

   # Deploy to Kubernetes
   kubectl apply -f k8s/
   ```

### Kubernetes Resources

The deployment includes:

#### Core Resources
- **Namespace**: `energy-trading` - Isolates resources
- **Deployment**: 3 replicas with rolling updates
- **Service**: ClusterIP service exposing port 80
- **Ingress**: HTTPS ingress with Let's Encrypt (optional)

#### Scaling & Reliability
- **HPA**: Auto-scaling based on CPU/memory (3-10 replicas)
- **PDB**: Ensures at least 1 pod during disruptions
- **Resource limits**: Memory and CPU limits set
- **Health checks**: Liveness and readiness probes

#### Security Features
- Non-root container execution
- Read-only root filesystem
- Dropped capabilities
- Security context configured

### Configuration

#### Environment Variables
```yaml
env:
- name: RUST_LOG
  value: "info"
- name: PORT
  value: "3000"
```bash

#### Resource Limits
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```bash

### Deployment Scripts

#### `deploy.sh` Usage
```bash
./deploy.sh [command]

Commands:
  build   - Build and push Docker image
  deploy  - Build, push, and deploy to Kubernetes (default)
  status  - Check deployment status
  cleanup - Remove deployment from Kubernetes
  help    - Show help message
```bash

#### Examples
```bash
# Full deployment
./deploy.sh deploy

# Check status
./deploy.sh status

# Clean up
./deploy.sh cleanup
```bash

### Accessing the Application

#### Local Development
```bash
# Port forward to access locally
kubectl port-forward svc/energy-trading-api-service 8080:80 -n energy-trading

# Access the API
curl http://localhost:8080/health
```bash

#### Production (with Ingress)
Update `k8s/ingress.yaml` with your domain:
```yaml
spec:
  tls:
  - hosts:
    - your-domain.com
    secretName: energy-trading-api-tls
  rules:
  - host: your-domain.com
```bash

### Monitoring & Observability

#### Health Checks
- **Liveness Probe**: `/health` endpoint
- **Readiness Probe**: `/health` endpoint
- **Startup time**: 30 seconds initial delay

#### Logs
```bash
# View logs
kubectl logs -f deployment/energy-trading-api -n energy-trading

# View specific pod logs
kubectl logs -f pod/energy-trading-api-xxx -n energy-trading
```bash

#### Metrics
```bash
# Get pod metrics
kubectl top pods -n energy-trading

# Get HPA status
kubectl get hpa -n energy-trading
```bash

### Troubleshooting

#### Common Issues

1. **Image Pull Errors**
   ```bash
   # Check image exists
   docker images | grep energy-trading-api

   # Update deployment with correct image
   kubectl set image deployment/energy-trading-api energy-trading-api=your-registry/energy-trading-api:latest -n energy-trading
   ```

2. **Pod Not Starting**
   ```bash
   # Check pod status
   kubectl describe pod -l app=energy-trading-api -n energy-trading

   # Check logs
   kubectl logs -l app=energy-trading-api -n energy-trading
   ```

3. **Service Not Accessible**
   ```bash
   # Check service endpoints
   kubectl get endpoints -n energy-trading

   # Test service internally
   kubectl run test-pod --image=curlimages/curl -it --rm --restart=Never -n energy-trading -- curl http://energy-trading-api-service/health
   ```

### Security Considerations

- Container runs as non-root user (UID 1000)
- Read-only root filesystem
- All capabilities dropped
- Security context enforced
- Resource limits prevent resource exhaustion
- Network policies can be added for additional isolation

### Scaling

#### Manual Scaling
```bash
# Scale to 5 replicas
kubectl scale deployment energy-trading-api --replicas=5 -n energy-trading
```bash

#### Auto-scaling
The HPA automatically scales based on:
- CPU utilization > 70%
- Memory utilization > 80%
- Min replicas: 3
- Max replicas: 10

### Updates

#### Rolling Updates
```bash
# Update image
kubectl set image deployment/energy-trading-api energy-trading-api=energy-trading-api:v2 -n energy-trading

# Check rollout status
kubectl rollout status deployment/energy-trading-api -n energy-trading

# Rollback if needed
kubectl rollout undo deployment/energy-trading-api -n energy-trading
```bash

### Production Checklist

- [ ] Container registry configured
- [ ] TLS certificates configured
- [ ] Resource limits appropriate for workload
- [ ] Monitoring and alerting set up
- [ ] Backup strategy for persistent data
- [ ] Network policies configured
- [ ] RBAC configured
- [ ] Ingress controller installed and configured
