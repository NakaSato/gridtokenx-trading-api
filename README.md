# Energy Trading API - Production-Ready REST Service

[![Rust](https://img.shields.io/badge/rust-%23000000.svg?style=for-the-badge&logo=rust&logoColor=white)](https://www.rust-lang.org/)
[![SQLx](https://img.shields.io/badge/sqlx-database-blue?style=for-the-badge)](https://github.com/launchbadge/sqlx)
[![Axum](https://img.shields.io/badge/ntex-web%20framework-orange?style=for-the-badge)](https://github.com/ntex-rs/ntex)
[![PostgreSQL](https://img.shields.io/badge/postgresql-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org/)

> A high-performance, production-ready REST API server for energy trading operations, built with Rust, ntex, and PostgreSQL for scalable deployment.
[![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)](https://sqlite.org/)

## 🚀 Features

- **🔥 High Performance**: Built with Rust and ntex for maximum throughput
- **🗄️ SQL Database**: SQLx with PostgreSQL support for production reliability
- **⚡ Async/Await**: Fully asynchronous with Tokio runtime
- **🌐 RESTful API**: Comprehensive REST endpoints for energy trading
- **📊 Production Ready**: Health checks, migrations, and proper error handling
- **🔒 Type Safety**: Compile-time verified SQL queries with SQLx
- **📈 Database Migrations**: Automated schema management
- **🎯 Modern Architecture**: Clean separation of concerns with proper abstractions

## 📋 Table of Contents

- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [API Endpoints](#-api-endpoints)
- [Database](#-database)
- [Configuration](#-configuration)
- [Development](#-development)
- [Migration from Blockchain](#-migration-from-blockchain)
- [Testing](#-testing)
- [Deployment](#-deployment)
- [Contributing](#-contributing)
- [License](#-license)

## 🛠️ Prerequisites

### Local Development
- **Rust**: 1.70+ with Cargo
- **Git**: For version control
- **Curl**: For API testing

### Docker Deployment
- **Docker**: 20.10+ with BuildKit support
- **Docker Compose**: 2.0+ (optional)

### Kubernetes Deployment
- **Kubernetes**: 1.25+ cluster
- **kubectl**: Configured for your cluster
- **Helm**: 3.0+ (optional, for advanced deployments)

### Optional Tools
- **hey**: HTTP load testing
- **jq**: JSON processing
- **k9s**: Kubernetes cluster management

## 📦 Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd energy-trading-api
```bash

### 2. Install Dependencies
```bash
# Install Rust if not already installed
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Verify installation
cargo --version
rustc --version
```bash

### 3. Build the Project
```bash
# Development build
cargo build

# Production build
cargo build --release
```bash

### 4. Run Tests
```bash
# Run all tests
cargo test

# Run with output
cargo test -- --nocapture
```bash

## Overview

This is the standalone API server for the Energy Trading Ledger system. It provides a RESTful HTTP interface to interact with the blockchain, token system, and energy trading functionality.

## Architecture

The API server is now separated from the core ledger library with complete containerization support:

```bash
energy-trading-api/          # API Server Project
├── src/
│   ├── main.rs              # API server entry point
│   ├── lib.rs               # Library exports
│   ├── handlers.rs          # HTTP request handlers
│   ├── middleware.rs        # CORS, logging, auth middleware
│   ├── models.rs            # API request/response models
│   ├── server.rs            # Server setup and routing
│   ├── auth.rs              # Authentication logic
│   ├── auth_handlers.rs     # Authentication endpoints
│   ├── blockchain_db.rs     # Blockchain database interface
│   ├── blockchain_db_impl.rs # Database implementations
│   ├── blockchain_config.rs # Configuration management
│   └── bin/
│       └── blockchain-cli.rs # CLI management tool
├── k8s/                     # Kubernetes manifests
│   ├── namespace.yaml       # Namespace definition
│   ├── deployment.yaml      # Deployment configuration
│   ├── service.yaml         # Service definition
│   ├── ingress.yaml         # Ingress configuration
│   ├── hpa.yaml             # Horizontal Pod Autoscaler
│   └── pdb.yaml             # Pod Disruption Budget
├── config/                  # Configuration files
│   ├── blockchain.toml      # Production configuration
│   ├── blockchain-dev.toml  # Development configuration
│   └── blockchain-hp.toml   # High-performance configuration
├── examples/
│   └── simple_client.rs     # Example client implementation
├── Dockerfile               # Multi-stage Docker build
├── .dockerignore           # Docker build optimization
├── deploy.sh               # Automated deployment script
├── DEPLOYMENT.md           # Detailed deployment guide
├── BLOCKCHAIN_DATABASE.md  # Database selection guide
├── Cargo.toml              # API dependencies
└── README.md               # This file

ledger/                      # Core Library Project
├── src/
│   ├── lib.rs               # Library exports
│   ├── main.rs              # CLI demo
│   ├── blockchain.rs        # Blockchain implementation
│   ├── token_system.rs      # Token system
│   ├── energy_trading.rs    # Energy trading logic
│   └── ...                  # Other core modules
└── Cargo.toml               # Core dependencies
```bash

## Blockchain Database

The Energy Trading API supports multiple blockchain database backends to meet different deployment requirements:

### Database Options

| Database | Use Case | Performance | Deployment | Features |
|----------|----------|-------------|------------|----------|
| **Memory** | Development, Testing | Excellent | Simple | No persistence |
| **RocksDB** | Production | Excellent | Simple | High performance, compression |
| **Sled** | Embedded | Good | Simple | Pure Rust, ACID transactions |
| **SQLite** | Small-Medium | Good | Simple | Human-readable, easy backup |
| **PostgreSQL** | Large Scale | Good | Complex | Advanced queries, analytics |
| **IPFS** | Decentralized | Fair | Complex | Content-addressable, distributed |

### Configuration

Choose your database backend using feature flags:

```toml
# Development (default)
[features]
default = ["memory-db"]

# Production
[features]
default = ["rocksdb-db"]

# Embedded
[features]
default = ["sled-db"]
```bash

Or configure via environment variables:

```bash
# Database configuration
export BLOCKCHAIN_DB_TYPE=rocksdb
export BLOCKCHAIN_DB_PATH=/var/lib/energy-trading/blockchain.db
export BLOCKCHAIN_ENABLE_CACHE=true
export BLOCKCHAIN_CACHE_SIZE=10000
```bash

### CLI Management

Use the built-in CLI tool for database management:

```bash
# Initialize blockchain database
cargo run --bin blockchain-cli init

# Show blockchain statistics
cargo run --bin blockchain-cli stats

# Verify blockchain integrity
cargo run --bin blockchain-cli verify

# Export blockchain data
cargo run --bin blockchain-cli export

# Show configuration
cargo run --bin blockchain-cli config
```bash

For detailed database selection guidance, see [BLOCKCHAIN_DATABASE.md](BLOCKCHAIN_DATABASE.md).

## Authentication

The API includes comprehensive authentication and authorization:

### Authentication Methods

- **JWT Tokens**: Stateless authentication with configurable expiration
- **API Keys**: Long-lived tokens for service-to-service communication
- **Role-Based Access Control**: Fine-grained permissions (admin, trader, readonly)

### User Management

```bash
# Register a new user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "trader1", "email": "trader1@example.com", "password": "secure123", "role": "trader"}'

# Login to get JWT token
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "trader1", "password": "secure123"}'
```bash

### API Key Management

```bash
# Create API key (requires JWT token)
curl -X POST http://localhost:3000/api/auth/api-keys \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Trading Bot", "permissions": ["read", "trade"], "expires_in_days": 30}'

# Use API key for requests
curl -X GET http://localhost:3000/api/energy/orders/buy \
  -H "X-API-Key: YOUR_API_KEY"
```bash

### Default Credentials

For development, a default admin user is created:
- **Username**: `admin`
- **Password**: `admin123`
- **Role**: `admin`

**⚠️ Change this password in production!**

## Quick Start

### 1. Build the API Server

```bash
cd energy-trading-api
cargo build --release
```bash

### 2. Run the API Server

```bash
cargo run
```bash

The server will start on `http://localhost:3000`.

### 3. Test the API

```bash
# Health check
curl http://localhost:3000/health

# Get blockchain info
curl http://localhost:3000/api/blockchain/info

# Create a prosumer
curl -X POST http://localhost:3000/api/energy/prosumers \
  -H "Content-Type: application/json" \
  -d '{"address": "alice", "name": "Alice Solar Farm"}'
```bash

## Dependencies

The API server depends on the `ledger-core` library:

```toml
[dependencies]
# Core ledger functionality
ledger-core = { path = "../ledger" }

# Web server framework
tokio = { version = "1.0", features = ["full"] }
axum = "0.7"
tower = "0.4"
tower-http = { version = "0.5", features = ["cors"] }

# Serialization
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["serde", "v4"] }
```bash

## API Endpoints

### Health Check
- `GET /health` - Server health status

### Blockchain
- `GET /api/blockchain/info` - Get blockchain information
- `GET /api/blockchain/blocks` - Get all blocks
- `GET /api/blockchain/blocks/:index` - Get specific block
- `POST /api/blockchain/mine` - Mine a new block
- `GET /api/blockchain/transactions/pending` - Get pending transactions

### Token System
- `POST /api/tokens/accounts` - Create token account
- `GET /api/tokens/balance/:address` - Get token balance
- `POST /api/tokens/transfer` - Transfer tokens
- `POST /api/tokens/stake` - Stake tokens
- `POST /api/tokens/unstake` - Unstake tokens
- `POST /api/tokens/rewards/:address` - Claim staking rewards

### Governance
- `GET /api/governance/proposals` - Get governance proposals
- `POST /api/governance/proposals` - Create governance proposal
- `POST /api/governance/vote` - Vote on proposal

### Energy Trading
- `POST /api/energy/prosumers` - Create prosumer
- `GET /api/energy/prosumers` - Get all prosumers
- `GET /api/energy/prosumers/:address` - Get specific prosumer
- `POST /api/energy/generation` - Update energy generation
- `POST /api/energy/consumption` - Update energy consumption
- `POST /api/energy/orders` - Create energy order
- `POST /api/energy/orders/cancel` - Cancel energy order
- `GET /api/energy/orders/buy` - Get buy orders
- `GET /api/energy/orders/sell` - Get sell orders
- `GET /api/energy/trades` - Get trade history
- `GET /api/energy/statistics` - Get market statistics

## Configuration

### Port Configuration

To change the server port, modify `src/main.rs`:

```rust
// Change from port 3000 to 8080
start_server(8080).await;
```bash

### CORS Configuration

CORS is configured in `src/middleware.rs`. For production, restrict origins:

```rust
pub fn cors_layer() -> CorsLayer {
    CorsLayer::new()
        .allow_origin("https://yourdomain.com".parse::<HeaderValue>().unwrap())
        .allow_methods([Method::GET, Method::POST])
        .allow_headers([CONTENT_TYPE])
}
```bash

## Development

### Adding New Endpoints

1. **Add request/response models** in `src/models.rs`
2. **Implement handlers** in `src/handlers.rs`
3. **Add routes** in `src/server.rs`

### Testing

#### Local Testing
Test the API using curl or any HTTP client:

```bash
# Health check
curl http://localhost:3000/health

# Create and test a prosumer
curl -X POST http://localhost:3000/api/energy/prosumers \
  -H "Content-Type: application/json" \
  -d '{"address": "test_user", "name": "Test User"}'

curl http://localhost:3000/api/energy/prosumers/test_user
```bash

#### Docker Testing
```bash
# Build and test container
docker build -t energy-trading-api:test .
docker run -p 3000:3000 energy-trading-api:test

# Test health endpoint
curl http://localhost:3000/health
```bash

#### Kubernetes Testing
```bash
# Deploy to test namespace
kubectl create namespace energy-trading-test
kubectl apply -f k8s/ -n energy-trading-test

# Port forward and test
kubectl port-forward svc/energy-trading-api-service 8080:80 -n energy-trading-test
curl http://localhost:8080/health

# Cleanup test environment
kubectl delete namespace energy-trading-test
```bash

#### Load Testing
```bash
# Install hey (HTTP load testing tool)
# macOS: brew install hey
# Linux: Download from https://github.com/rakyll/hey

# Basic load test
hey -z 30s -c 10 http://localhost:3000/health

# Test with POST requests
hey -z 30s -c 5 -m POST -H "Content-Type: application/json" \
  -d '{"address": "test", "name": "Test"}' \
  http://localhost:3000/api/energy/prosumers
```bash

### Testing & Validation

The project includes comprehensive testing and validation scripts:

#### Quick API Testing
```bash
# Basic API functionality test
./test_api.sh
```bash

#### PostgreSQL Integration Testing
```bash
# Test with PostgreSQL database
./test_postgres.sh
```bash

#### Comprehensive Test Suite
```bash
# Run all tests (unit, integration, API)
./run_tests.sh

# Run specific test types
./run_tests.sh --unit              # Unit tests only
./run_tests.sh --api               # API tests only
./run_tests.sh --performance       # Include performance tests
./run_tests.sh --coverage          # Generate code coverage

# Verbose output
./run_tests.sh --verbose
```bash

#### Project Validation
```bash
# Validate entire project setup
./validate_project.sh

# Quick validation (no server tests)
./validate_project.sh --quick

# Skip specific validations
./validate_project.sh --no-build --no-db
```bash

#### Specialized Tests
```bash
# Test order cancellation functionality
./test_cancel_fix.sh

# Clean and format all scripts/docs
./clean_project.sh
```bash
./test_api.sh

# Or run specific tests
cargo test
cargo test --lib
cargo test --integration
```bash

## Production Deployment

### 🐳 Docker Deployment

The project includes a production-ready multi-stage Dockerfile optimized for Rust applications:

#### Quick Start
```bash
# Build the Docker image
docker build -t energy-trading-api:latest .

# Run the container
docker run -p 3000:3000 energy-trading-api:latest

# Test the API
curl http://localhost:3000/health
```bash

#### Docker Features
- **Multi-stage build**: Optimized for smaller image size
- **Security**: Non-root user execution (UID 1000)
- **Health checks**: Built-in health monitoring
- **Optimized caching**: Dependencies cached separately

#### Environment Variables
```bash
# Configure logging level
docker run -e RUST_LOG=debug -p 3000:3000 energy-trading-api:latest

# Configure custom port
docker run -e PORT=8080 -p 8080:8080 energy-trading-api:latest
```bash

### ☸️ Kubernetes Deployment

Complete Kubernetes manifests are provided in the `k8s/` directory for production-ready deployment.

#### Quick Deployment
```bash
# Deploy everything with one command
./deploy.sh

# Or apply manifests manually
kubectl apply -f k8s/
```bash

#### Kubernetes Resources
- **Namespace**: `energy-trading` - Isolated environment
- **Deployment**: 3 replicas with rolling updates
- **Service**: ClusterIP for internal communication
- **Ingress**: HTTPS with Let's Encrypt support
- **HPA**: Auto-scaling (3-10 replicas)
- **PDB**: High availability during updates

#### Access the Application
```bash
# Port forward for local access
kubectl port-forward svc/energy-trading-api-service 8080:80 -n energy-trading

# Test the API
curl http://localhost:8080/health
```bash

#### Monitoring & Scaling
```bash
# Check pod status
kubectl get pods -n energy-trading

# View logs
kubectl logs -f deployment/energy-trading-api -n energy-trading

# Check auto-scaling
kubectl get hpa -n energy-trading

# Manual scaling
kubectl scale deployment energy-trading-api --replicas=5 -n energy-trading
```bash

### 🛠️ Deployment Script

The `deploy.sh` script provides automated deployment capabilities:

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

# Build image only
./deploy.sh build

# Check deployment status
./deploy.sh status

# Clean up everything
./deploy.sh cleanup
```bash

### 🔒 Security Features

#### Container Security
- Non-root user execution
- Read-only root filesystem
- Dropped capabilities
- Security contexts configured
- Resource limits enforced

#### Kubernetes Security
- Pod Security Standards compliant
- Network policies ready
- RBAC compatible
- Secrets management
- TLS termination

### 📊 Production Configuration

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

#### Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```bash

#### Auto-scaling Configuration
```yaml
# HPA scales based on:
# - CPU utilization > 70%
# - Memory utilization > 80%
# - Min replicas: 3
# - Max replicas: 10
```bash

### 🌐 Ingress Configuration

For production HTTPS access, update `k8s/ingress.yaml`:

```yaml
spec:
  tls:
  - hosts:
    - your-domain.com
    secretName: energy-trading-api-tls
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: energy-trading-api-service
            port:
              number: 80
```bash

### 🔧 Troubleshooting

#### Common Issues

1. **Image Pull Errors**
   ```bash
   # Check if image exists
   docker images | grep energy-trading-api

   # Update deployment
   kubectl set image deployment/energy-trading-api energy-trading-api=energy-trading-api:latest -n energy-trading
   ```

2. **Pod Not Starting**
   ```bash
   # Check pod details
   kubectl describe pod -l app=energy-trading-api -n energy-trading

   # Check logs
   kubectl logs -l app=energy-trading-api -n energy-trading
   ```

3. **Service Not Accessible**
   ```bash
   # Check service endpoints
   kubectl get endpoints -n energy-trading

   # Test internal connectivity
   kubectl run test-pod --image=curlimages/curl -it --rm --restart=Never -n energy-trading -- curl http://energy-trading-api-service/health
   ```

### 📚 Additional Documentation

For detailed information, see:
- **[POSTGRESQL_SETUP.md](POSTGRESQL_SETUP.md)** - PostgreSQL setup and configuration
- **[REVERSE_PROXY_GUIDE.md](REVERSE_PROXY_GUIDE.md)** - Production reverse proxy setup
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Comprehensive deployment guide
- **`k8s/`** directory - Kubernetes manifests and configurations
- **`migrations/`** directory - Database schema migrations

### 🛠️ Available Scripts

The project includes several utility scripts for development and deployment:

| Script | Purpose | Usage |
|--------|---------|-------|
| **`setup_postgres.sh`** | PostgreSQL setup and configuration | `./setup_postgres.sh [options]` |
| **`test_api.sh`** | Basic API functionality testing | `./test_api.sh` |
| **`test_postgres.sh`** | PostgreSQL integration testing | `./test_postgres.sh` |
| **`test_cancel_fix.sh`** | Order cancellation functionality test | `./test_cancel_fix.sh` |
| **`run_tests.sh`** | Comprehensive test suite runner | `./run_tests.sh [options]` |
| **`validate_project.sh`** | Complete project validation | `./validate_project.sh [options]` |
| **`deploy.sh`** | Kubernetes deployment automation | `./deploy.sh [command]` |
| **`clean_project.sh`** | Code formatting and cleanup | `./clean_project.sh` |

#### Script Examples

```bash
# Setup PostgreSQL with custom settings
./setup_postgres.sh --db-name mydb --user myuser --password mypass

# Run comprehensive tests with coverage
./run_tests.sh --coverage --verbose

# Quick project validation
./validate_project.sh --quick

# Deploy to Kubernetes with custom registry
REGISTRY=myregistry.com/ ./deploy.sh deploy

# Check deployment status
./deploy.sh status
```bash

All scripts include detailed help information accessible with the `--help` flag.

### 🚀 Production Checklist

- [ ] Container registry configured
- [ ] TLS certificates set up
- [ ] Resource limits appropriate
- [ ] Monitoring and alerting configured
- [ ] Backup strategy implemented
- [ ] Network policies configured
- [ ] RBAC configured
- [ ] Ingress controller installed

## Benefits of Separation

### 1. **Modularity**
- Core ledger logic is separate from API concerns
- API can be deployed independently
- Core library can be reused in other projects

### 2. **Scalability**
- API server can be scaled horizontally
- Multiple API instances can use the same core library
- Different API versions can coexist

### 3. **Development**
- API and core can be developed independently
- Easier testing and debugging
- Clear separation of responsibilities

### 4. **Deployment**
- API server can be deployed without core CLI tools
- Smaller deployment footprint
- Better resource utilization

## Future Enhancements

### 🔐 Security & Authentication
- [ ] Add JWT authentication middleware
- [ ] Implement OAuth2/OpenID Connect
- [ ] Add API key management
- [ ] Implement rate limiting and DDoS protection

### 📊 Monitoring & Observability
- [ ] Add Prometheus metrics endpoint
- [ ] Implement distributed tracing (Jaeger/Zipkin)
- [ ] Add structured logging with correlation IDs
- [ ] Create Grafana dashboards

### 🚀 Performance & Scalability
- [ ] Implement Redis caching layer
- [ ] Add connection pooling
- [ ] Implement GraphQL API
- [ ] Add API response compression

### 🗄️ Data & Persistence
- [ ] Add PostgreSQL persistence layer
- [ ] Implement database migrations
- [ ] Add backup and recovery procedures
- [ ] Create data replication strategy

### 🔄 CI/CD & DevOps
- [ ] Add GitHub Actions workflows
- [ ] Implement automated testing pipeline
- [ ] Add Helm charts for Kubernetes
- [ ] Create staging environment

### 📱 Client SDKs & Documentation
- [ ] Create OpenAPI/Swagger documentation
- [ ] Generate TypeScript client SDK
- [ ] Create Python client SDK
- [ ] Add REST API testing suite

### 🌐 Advanced Kubernetes Features
- [ ] Implement service mesh (Istio)
- [ ] Add network policies
- [ ] Create custom resource definitions (CRDs)
- [ ] Implement GitOps with ArgoCD

### 🔧 Operational Excellence
- [ ] Add automated backup procedures
- [ ] Implement blue-green deployments
- [ ] Create disaster recovery procedures
- [ ] Add capacity planning tools

## Related Projects

- **ledger-core** - Core blockchain and trading logic
- **energy-trading-web** - Web frontend (future)
- **energy-trading-mobile** - Mobile app (future)

## License

This project is part of the Energy Trading Ledger ecosystem.
