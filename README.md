# Energy Trading API - Separated Backend Service

## Overview

This is the standalone API server for the Energy Trading Ledger system. It provides a RESTful HTTP interface to interact with the blockchain, token system, and energy trading functionality.

## Architecture

The API server is now separated from the core ledger library:

```
energy-trading-api/          # API Server Project
├── src/
│   ├── main.rs              # API server entry point
│   ├── lib.rs               # Library exports
│   ├── handlers.rs          # HTTP request handlers
│   ├── middleware.rs        # CORS, logging, auth middleware
│   ├── models.rs            # API request/response models
│   └── server.rs            # Server setup and routing
├── Cargo.toml               # API dependencies
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
```

## Quick Start

### 1. Build the API Server

```bash
cd energy-trading-api
cargo build --release
```

### 2. Run the API Server

```bash
cargo run
```

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
```

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
```

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
```

### CORS Configuration

CORS is configured in `src/middleware.rs`. For production, restrict origins:

```rust
pub fn cors_layer() -> CorsLayer {
    CorsLayer::new()
        .allow_origin("https://yourdomain.com".parse::<HeaderValue>().unwrap())
        .allow_methods([Method::GET, Method::POST])
        .allow_headers([CONTENT_TYPE])
}
```

## Development

### Adding New Endpoints

1. **Add request/response models** in `src/models.rs`
2. **Implement handlers** in `src/handlers.rs`
3. **Add routes** in `src/server.rs`

### Testing

Test the API using curl or any HTTP client:

```bash
# Example: Create and test a prosumer
curl -X POST http://localhost:3000/api/energy/prosumers \
  -H "Content-Type: application/json" \
  -d '{"address": "test_user", "name": "Test User"}'

curl http://localhost:3000/api/energy/prosumers/test_user
```

## Production Deployment

### Docker

Create a `Dockerfile`:

```dockerfile
FROM rust:1.70 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bullseye-slim
COPY --from=builder /app/target/release/api-server /usr/local/bin/
EXPOSE 3000
CMD ["api-server"]
```

### Systemd Service

Create `/etc/systemd/system/energy-trading-api.service`:

```ini
[Unit]
Description=Energy Trading API Server
After=network.target

[Service]
Type=simple
User=api
WorkingDirectory=/opt/energy-trading-api
ExecStart=/opt/energy-trading-api/target/release/api-server
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

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

- [ ] Add authentication middleware
- [ ] Implement rate limiting
- [ ] Add API versioning
- [ ] Create OpenAPI/Swagger documentation
- [ ] Add metrics and monitoring
- [ ] Implement caching layer
- [ ] Add database persistence
- [ ] Create client SDKs

## Related Projects

- **ledger-core** - Core blockchain and trading logic
- **energy-trading-web** - Web frontend (future)
- **energy-trading-mobile** - Mobile app (future)

## License

This project is part of the Energy Trading Ledger ecosystem.
