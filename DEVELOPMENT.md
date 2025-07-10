# Development Guide - Energy Trading API

This guide provides comprehensive information for developers working on the Energy Trading API project.

## 📋 Table of Contents

- [Development Environment](#development-environment)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing Strategy](#testing-strategy)
- [Database Development](#database-development)
- [API Development](#api-development)
- [Performance Guidelines](#performance-guidelines)
- [Security Guidelines](#security-guidelines)
- [Deployment Process](#deployment-process)

## 🛠️ Development Environment

### Prerequisites

- **Rust**: 1.70+ with Cargo
- **PostgreSQL**: 13+ for database development
- **Docker**: 20.10+ (optional, for containerized development)
- **kubectl**: For Kubernetes development (optional)
- **Git**: For version control

### IDE Setup

#### VS Code (Recommended)
```bash
# Install Rust extension
code --install-extension rust-lang.rust-analyzer
code --install-extension vadimcn.vscode-lldb
code --install-extension serayuzgur.crates

# Install additional tools
cargo install cargo-edit
cargo install cargo-watch
cargo install cargo-tarpaulin  # For coverage
```bash

#### Vim/Neovim
```bash
# Install rust-analyzer language server
rustup component add rust-analyzer
```bash

### Environment Setup

1. **Clone and setup the project**:
   ```bash
   git clone <repository-url>
   cd energy-trading-api
   ./setup_postgres.sh  # Setup PostgreSQL
   cargo build          # Build the project
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Run initial validation**:
   ```bash
   ./validate_project.sh --quick
   ```

## 📁 Project Structure

```bash
energy-trading-api/
├── src/                     # Source code
│   ├── main.rs             # Application entry point
│   ├── lib.rs              # Library exports
│   ├── server.rs           # Server configuration
│   ├── handlers.rs         # HTTP request handlers
│   ├── middleware.rs       # Custom middleware
│   ├── models.rs           # Data models
│   ├── database.rs         # Database layer
│   ├── auth.rs             # Authentication logic
│   └── auth_handlers.rs    # Auth endpoints
├── migrations/             # Database migrations
├── k8s/                   # Kubernetes manifests
├── tests/                 # Integration tests
├── examples/              # Example code
├── scripts/               # Utility scripts (*.sh)
├── docs/                  # Additional documentation
└── target/                # Build artifacts (git ignored)
```bash

### Code Organization Principles

1. **Separation of Concerns**: Each module has a specific responsibility
2. **Layered Architecture**: Clear separation between handlers, business logic, and data
3. **Dependency Injection**: Use traits for testability
4. **Error Handling**: Consistent error types and propagation

## 🔄 Development Workflow

### Daily Development

1. **Start development session**:
   ```bash
   # Update dependencies
   cargo update
   
   # Start file watcher for automatic rebuilds
   cargo watch -x 'run'
   ```

2. **Make changes**:
   - Write code following our style guide
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**:
   ```bash
   # Run tests
   ./run_tests.sh --verbose
   
   # Validate the project
   ./validate_project.sh
   ```

4. **Before committing**:
   ```bash
   # Format code
   cargo fmt
   
   # Check for issues
   cargo clippy
   
   # Clean and format scripts/docs
   ./clean_project.sh
   ```

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make commits with meaningful messages
git commit -m "feat: add order cancellation endpoint"

# Push and create PR
git push origin feature/your-feature-name
```bash

### Commit Message Format

Use conventional commits:
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `test:` - Test additions/changes
- `refactor:` - Code refactoring
- `perf:` - Performance improvements
- `chore:` - Maintenance tasks

## 📏 Code Standards

### Rust Style Guide

Follow the official Rust style guide with these additions:

#### Naming Conventions
```rust
// Use snake_case for functions and variables
fn create_energy_order() -> Result<Order, Error> { }

// Use PascalCase for types
struct EnergyOrder {
    trader_address: String,
    energy_amount: f64,
}

// Use SCREAMING_SNAKE_CASE for constants
const MAX_ORDER_SIZE: f64 = 1000.0;

// Use descriptive names
let pending_orders = get_pending_orders(); // Good
let po = get_orders();                     // Bad
```bash

#### Error Handling
```rust
// Use Result types for fallible operations
async fn create_order(order: NewOrder) -> Result<Order, ApiError> {
    validate_order(&order)?;
    let saved_order = database::save_order(order).await?;
    Ok(saved_order)
}

// Implement Display and Error traits for custom errors
#[derive(Debug, thiserror::Error)]
pub enum ApiError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("Validation error: {message}")]
    Validation { message: String },
}
```bash

#### Documentation
```rust
/// Creates a new energy trading order
/// 
/// # Arguments
/// 
/// * `order` - The order details to create
/// 
/// # Returns
/// 
/// Returns the created order with assigned ID, or an error if creation fails
/// 
/// # Examples
/// 
/// ```rust
/// let order = NewOrder {
///     trader_address: "alice".to_string(),
///     order_type: OrderType::Buy,
///     energy_amount: 100.0,
///     price_per_kwh: 0.15,
/// };
/// let created = create_order(order).await?;
/// ```
pub async fn create_order(order: NewOrder) -> Result<Order, ApiError> {
    // Implementation
}
```bash

### Database Conventions

#### Migration Files
```sql
-- migrations/20240101000001_descriptive_name.sql
-- Use descriptive names and timestamps
-- Include both UP and DOWN migrations

-- UP Migration
CREATE TABLE energy_orders (
    id SERIAL PRIMARY KEY,
    trader_address VARCHAR(255) NOT NULL,
    order_type VARCHAR(10) NOT NULL CHECK (order_type IN ('buy', 'sell')),
    energy_amount DECIMAL(10,3) NOT NULL CHECK (energy_amount > 0),
    price_per_kwh DECIMAL(8,4) NOT NULL CHECK (price_per_kwh > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_energy_orders_trader ON energy_orders(trader_address);
CREATE INDEX idx_energy_orders_status ON energy_orders(status);
CREATE INDEX idx_energy_orders_type ON energy_orders(order_type);
```bash

#### Query Patterns
```rust
// Use compile-time checked queries with sqlx
async fn get_orders_by_trader(
    pool: &PgPool,
    trader_address: &str
) -> Result<Vec<Order>, sqlx::Error> {
    sqlx::query_as!(
        Order,
        r#"
        SELECT id, trader_address, order_type, energy_amount, 
               price_per_kwh, status, created_at, updated_at
        FROM energy_orders 
        WHERE trader_address = $1 
        ORDER BY created_at DESC
        "#,
        trader_address
    )
    .fetch_all(pool)
    .await
}
```bash

## 🧪 Testing Strategy

### Test Organization

```bash
tests/
├── unit/               # Unit tests (in src/ files)
├── integration/        # Integration tests
│   ├── api/           # API endpoint tests
│   ├── database/      # Database tests
│   └── auth/          # Authentication tests
└── fixtures/          # Test data and utilities
```bash

### Unit Tests
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_order_validation() {
        let order = NewOrder {
            trader_address: "alice".to_string(),
            order_type: OrderType::Buy,
            energy_amount: 100.0,
            price_per_kwh: 0.15,
        };
        
        assert!(validate_order(&order).is_ok());
    }

    #[test]
    fn test_invalid_order_amount() {
        let order = NewOrder {
            trader_address: "alice".to_string(),
            order_type: OrderType::Buy,
            energy_amount: -10.0, // Invalid
            price_per_kwh: 0.15,
        };
        
        assert!(validate_order(&order).is_err());
    }
}
```bash

### Integration Tests
```rust
// tests/integration/api/orders.rs
use sqlx::PgPool;
use tower::ServiceExt;

#[sqlx::test]
async fn test_create_order_endpoint(pool: PgPool) {
    let app = create_test_app(pool).await;
    
    let order = serde_json::json!({
        "trader_address": "alice",
        "order_type": "buy",
        "energy_amount": 100.0,
        "price_per_kwh": 0.15
    });
    
    let response = app
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/energy/orders")
                .header("content-type", "application/json")
                .body(Body::from(order.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
        
    assert_eq!(response.status(), StatusCode::CREATED);
}
```bash

### Test Data Management
```rust
// tests/fixtures/mod.rs
pub struct TestOrder {
    pub trader_address: String,
    pub order_type: OrderType,
    pub energy_amount: f64,
    pub price_per_kwh: f64,
}

impl TestOrder {
    pub fn builder() -> TestOrderBuilder {
        TestOrderBuilder::default()
    }
}

pub struct TestOrderBuilder {
    order: TestOrder,
}

impl TestOrderBuilder {
    pub fn trader(mut self, address: &str) -> Self {
        self.order.trader_address = address.to_string();
        self
    }
    
    pub fn buy_order(mut self) -> Self {
        self.order.order_type = OrderType::Buy;
        self
    }
    
    pub fn build(self) -> TestOrder {
        self.order
    }
}
```bash

## 🗄️ Database Development

### Migration Best Practices

1. **Always write reversible migrations**
2. **Test migrations on production-like data**
3. **Use transactions for complex migrations**
4. **Add appropriate indexes**
5. **Validate constraints**

### Schema Design Principles

```sql
-- Use appropriate data types
CREATE TABLE energy_trades (
    id BIGSERIAL PRIMARY KEY,           -- Auto-incrementing ID
    buy_order_id BIGINT NOT NULL,       -- Foreign key reference
    sell_order_id BIGINT NOT NULL,
    energy_amount DECIMAL(12,6) NOT NULL, -- Precise decimal for energy
    price_per_kwh DECIMAL(10,4) NOT NULL, -- Precise decimal for price
    trade_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Foreign key constraints
    FOREIGN KEY (buy_order_id) REFERENCES energy_orders(id),
    FOREIGN KEY (sell_order_id) REFERENCES energy_orders(id),
    
    -- Check constraints
    CONSTRAINT positive_energy CHECK (energy_amount > 0),
    CONSTRAINT positive_price CHECK (price_per_kwh > 0)
);

-- Create indexes for query performance
CREATE INDEX idx_trades_timestamp ON energy_trades(trade_timestamp);
CREATE INDEX idx_trades_buy_order ON energy_trades(buy_order_id);
CREATE INDEX idx_trades_sell_order ON energy_trades(sell_order_id);
```bash

### Connection Management

```rust
// Use connection pooling
pub async fn create_db_pool(database_url: &str) -> Result<PgPool, sqlx::Error> {
    PgPoolOptions::new()
        .max_connections(20)
        .min_connections(5)
        .acquire_timeout(Duration::from_secs(10))
        .idle_timeout(Duration::from_secs(600))
        .max_lifetime(Duration::from_secs(1800))
        .connect(database_url)
        .await
}
```bash

## 🌐 API Development

### Handler Structure

```rust
// Consistent handler structure
pub async fn create_order(
    State(state): State<AppState>,
    Json(payload): Json<CreateOrderRequest>,
) -> Result<Json<ApiResponse<Order>>, ApiError> {
    // 1. Validate input
    payload.validate()?;
    
    // 2. Perform business logic
    let order = state.order_service
        .create_order(payload.into())
        .await?;
    
    // 3. Return response
    Ok(Json(ApiResponse::success(order)))
}
```bash

### Request/Response Models

```rust
// Request models with validation
#[derive(Debug, Deserialize, Validate)]
pub struct CreateOrderRequest {
    #[validate(length(min = 1, max = 255))]
    pub trader_address: String,
    
    pub order_type: OrderType,
    
    #[validate(range(min = 0.001, max = 10000.0))]
    pub energy_amount: f64,
    
    #[validate(range(min = 0.001, max = 100.0))]
    pub price_per_kwh: f64,
}

// Response models with consistent structure
#[derive(Debug, Serialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
    pub timestamp: DateTime<Utc>,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
            timestamp: Utc::now(),
        }
    }
}
```bash

### Error Handling

```rust
// Centralized error handling
#[derive(Debug, thiserror::Error)]
pub enum ApiError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    
    #[error("Validation error: {0}")]
    Validation(#[from] validator::ValidationErrors),
    
    #[error("Not found: {resource}")]
    NotFound { resource: String },
    
    #[error("Unauthorized")]
    Unauthorized,
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            ApiError::Database(e) => {
                tracing::error!("Database error: {}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal server error")
            }
            ApiError::Validation(e) => {
                (StatusCode::BAD_REQUEST, &e.to_string())
            }
            ApiError::NotFound { .. } => {
                (StatusCode::NOT_FOUND, &self.to_string())
            }
            ApiError::Unauthorized => {
                (StatusCode::UNAUTHORIZED, "Unauthorized")
            }
        };

        let body = Json(serde_json::json!({
            "success": false,
            "error": error_message,
            "timestamp": Utc::now()
        }));

        (status, body).into_response()
    }
}
```bash

## ⚡ Performance Guidelines

### Database Performance

1. **Use appropriate indexes**
2. **Limit query results**
3. **Use connection pooling**
4. **Implement query timeouts**
5. **Monitor slow queries**

```rust
// Efficient pagination
pub async fn get_orders_paginated(
    pool: &PgPool,
    limit: i64,
    offset: i64,
) -> Result<Vec<Order>, sqlx::Error> {
    sqlx::query_as!(
        Order,
        "SELECT * FROM energy_orders ORDER BY created_at DESC LIMIT $1 OFFSET $2",
        limit,
        offset
    )
    .fetch_all(pool)
    .await
}
```bash

### Memory Management

```rust
// Use streams for large datasets
pub async fn export_orders(
    pool: &PgPool,
) -> impl Stream<Item = Result<Order, sqlx::Error>> {
    sqlx::query_as::<_, Order>("SELECT * FROM energy_orders")
        .fetch(pool)
}
```bash

### Caching Strategy

```rust
// Implement caching for frequently accessed data
use moka::future::Cache;

pub struct OrderService {
    db_pool: PgPool,
    cache: Cache<String, Order>,
}

impl OrderService {
    pub async fn get_order(&self, id: &str) -> Result<Order, ApiError> {
        if let Some(order) = self.cache.get(id).await {
            return Ok(order);
        }
        
        let order = self.fetch_order_from_db(id).await?;
        self.cache.insert(id.to_string(), order.clone()).await;
        Ok(order)
    }
}
```bash

## 🔒 Security Guidelines

### Input Validation
- Always validate and sanitize input
- Use type-safe deserialization
- Implement rate limiting
- Validate business rules

### Authentication & Authorization
```rust
// JWT middleware
pub async fn auth_middleware(
    State(state): State<AppState>,
    mut req: Request<Body>,
    next: Next<Body>,
) -> Result<Response, ApiError> {
    let token = extract_token(&req)?;
    let claims = verify_jwt(&token, &state.jwt_secret)?;
    
    // Add user info to request extensions
    req.extensions_mut().insert(claims);
    
    Ok(next.run(req).await)
}
```bash

### Data Protection
- Use HTTPS in production
- Encrypt sensitive data at rest
- Implement proper logging (avoid logging sensitive data)
- Use environment variables for secrets

## 🚀 Deployment Process

### Local Development
```bash
# Start development server
cargo run

# Run with file watching
cargo watch -x run
```bash

### Testing Environment
```bash
# Run comprehensive tests
./run_tests.sh --coverage

# Validate entire project
./validate_project.sh
```bash

### Production Deployment
```bash
# Build and deploy
./deploy.sh deploy

# Check deployment status
./deploy.sh status

# Monitor logs
kubectl logs -f deployment/energy-trading-api -n energy-trading
```bash

### Environment Configuration

| Environment | Database | Logging | Debug | Features |
|------------|----------|---------|-------|----------|
| Development | PostgreSQL (local) | Debug | Enabled | All |
| Testing | PostgreSQL (test) | Info | Enabled | All |
| Staging | PostgreSQL (staging) | Info | Disabled | Production |
| Production | PostgreSQL (prod) | Warn | Disabled | Production |

## 📝 Contributing Guidelines

1. **Follow the coding standards** outlined in this guide
2. **Write comprehensive tests** for new functionality
3. **Update documentation** for API changes
4. **Use conventional commits** for clear history
5. **Run the full test suite** before submitting PRs
6. **Add appropriate logging** for debugging and monitoring

## 🔍 Debugging Tips

### Common Issues

1. **Database Connection Issues**
   ```bash
   # Check PostgreSQL status
   pg_isready -h localhost -p 5432
   
   # Test connection manually
   psql $DATABASE_URL -c "SELECT 1;"
   ```

2. **Port Already in Use**
   ```bash
   # Find process using port 3000
   lsof -i :3000
   
   # Kill process
   kill -9 <PID>
   ```

3. **Migration Issues**
   ```bash
   # Check migration status
   sqlx migrate info
   
   # Revert last migration
   sqlx migrate revert
   ```

### Debugging Tools

```rust
// Add debug logging
tracing::debug!("Processing order: {:?}", order);

// Use dbg! macro for quick debugging
let result = dbg!(some_computation());

// Add timing information
let start = Instant::now();
let result = expensive_operation().await;
tracing::info!("Operation took: {:?}", start.elapsed());
```bash

---

For additional help, refer to the project documentation or create an issue in the repository.
