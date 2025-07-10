# Simple Database Configuration for Energy Trading API

## Database Requirements Analysis

### What You Actually Need:
- **User Authentication Storage**: Users, API keys, sessions
- **Business Data Storage**: Energy orders, trades, prosumers, market data
- **API Operational Data**: Logs, metrics, configuration
- **Simple & Reliable**: PostgreSQL, MySQL, or SQLite for production

### What You DON'T Need:
- Full blockchain with blocks and merkle trees
- Multiple consensus algorithms
- Decentralized storage (unless building a blockchain network)
- Complex blockchain validation

## Recommended Simple Database Architecture

### Option 1: PostgreSQL (Recommended for Production)
```bash
# Environment variables
DATABASE_URL=postgresql://user:pass@localhost/energy_trading
DB_POOL_SIZE=10
DB_TIMEOUT_SECONDS=30
```

### Option 2: SQLite (Good for Development/Small Scale)
```bash
# Environment variables
DATABASE_URL=sqlite:./energy_trading.db
```

### Option 3: MySQL (Alternative Production Option)
```bash
# Environment variables
DATABASE_URL=mysql://user:pass@localhost/energy_trading
```

## Simple Database Schema

### Tables Needed:
1. **users** - User accounts and authentication
2. **api_keys** - API key management
3. **prosumers** - Energy prosumer information
4. **energy_orders** - Buy/sell orders
5. **energy_trades** - Completed trades
6. **market_statistics** - Market data and analytics
7. **audit_logs** - API access logs

### SQL Schema Example:
```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'trader',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP
);

-- API Keys table
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL,
    permissions TEXT[] DEFAULT ARRAY['read'],
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    last_used TIMESTAMP
);

-- Prosumers table
CREATE TABLE prosumers (
    address VARCHAR(100) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    energy_generated DECIMAL(15,2) DEFAULT 0,
    energy_consumed DECIMAL(15,2) DEFAULT 0,
    grid_tokens DECIMAL(15,2) DEFAULT 0,
    watt_tokens DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Energy Orders table
CREATE TABLE energy_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trader_address VARCHAR(100) NOT NULL,
    order_type VARCHAR(10) NOT NULL CHECK (order_type IN ('buy', 'sell')),
    energy_amount DECIMAL(15,2) NOT NULL,
    price_per_kwh DECIMAL(10,4) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Energy Trades table
CREATE TABLE energy_trades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buy_order_id UUID REFERENCES energy_orders(id),
    sell_order_id UUID REFERENCES energy_orders(id),
    buyer_address VARCHAR(100) NOT NULL,
    seller_address VARCHAR(100) NOT NULL,
    energy_amount DECIMAL(15,2) NOT NULL,
    price_per_kwh DECIMAL(10,4) NOT NULL,
    total_price DECIMAL(15,2) NOT NULL,
    executed_at TIMESTAMP DEFAULT NOW()
);

-- Market Statistics table
CREATE TABLE market_statistics (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    total_trades INTEGER DEFAULT 0,
    total_volume DECIMAL(15,2) DEFAULT 0,
    average_price DECIMAL(10,4) DEFAULT 0,
    highest_price DECIMAL(10,4) DEFAULT 0,
    lowest_price DECIMAL(10,4) DEFAULT 0,
    active_buy_orders INTEGER DEFAULT 0,
    active_sell_orders INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## Implementation Recommendation

### 1. Use SQLx (Rust SQL Toolkit)
```toml
[dependencies]
sqlx = { version = "0.7", features = ["runtime-tokio-rustls", "postgres", "chrono", "uuid"] }
```

### 2. Simple Database Service
```rust
use sqlx::{PgPool, Row};
use uuid::Uuid;

pub struct DatabaseService {
    pool: PgPool,
}

impl DatabaseService {
    pub async fn new(database_url: &str) -> Result<Self, sqlx::Error> {
        let pool = PgPool::connect(database_url).await?;
        Ok(Self { pool })
    }

    pub async fn create_user(&self, username: &str, email: &str, password_hash: &str) -> Result<Uuid, sqlx::Error> {
        let row = sqlx::query!(
            "INSERT INTO users (username, email, password_hash) VALUES ($1, $2, $3) RETURNING id",
            username, email, password_hash
        )
        .fetch_one(&self.pool)
        .await?;
        
        Ok(row.id)
    }

    pub async fn get_user_by_username(&self, username: &str) -> Result<Option<User>, sqlx::Error> {
        let row = sqlx::query_as!(
            User,
            "SELECT * FROM users WHERE username = $1 AND is_active = true",
            username
        )
        .fetch_optional(&self.pool)
        .await?;
        
        Ok(row)
    }

    // Add more methods for energy orders, trades, etc.
}
```

### 3. Environment Configuration
```bash
# .env file
DATABASE_URL=postgresql://energy_user:secure_password@localhost/energy_trading
JWT_SECRET=your-super-secret-jwt-key
API_HOST=0.0.0.0
API_PORT=3000
```

## Migration Strategy

### From Current Implementation:
1. **Remove**: Blockchain database complexity
2. **Keep**: Authentication system (it's good!)
3. **Add**: Simple SQL database with proper schema
4. **Simplify**: Focus on API functionality, not blockchain features

### Implementation Steps:
1. Choose database (PostgreSQL recommended)
2. Create database schema with migrations
3. Implement simple database service
4. Update handlers to use SQL database
5. Remove blockchain complexity

Would you like me to implement this simpler, more practical database solution instead?
