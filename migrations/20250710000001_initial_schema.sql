-- Create users table
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'trader',
    is_active BOOLEAN DEFAULT true,
    created_at TEXT DEFAULT (datetime('now')),
    last_login TEXT
);

-- Create API keys table
CREATE TABLE api_keys (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    key_hash TEXT NOT NULL,
    permissions TEXT DEFAULT 'read',
    is_active BOOLEAN DEFAULT true,
    expires_at TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    last_used TEXT
);

-- Create prosumers table
CREATE TABLE prosumers (
    address TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    energy_generated REAL DEFAULT 0,
    energy_consumed REAL DEFAULT 0,
    grid_tokens REAL DEFAULT 0,
    watt_tokens REAL DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

-- Create orders table
CREATE TABLE orders (
    id TEXT PRIMARY KEY,
    prosumer_address TEXT NOT NULL,
    order_type TEXT NOT NULL CHECK (order_type IN ('buy', 'sell')),
    energy_amount REAL NOT NULL CHECK (energy_amount > 0),
    price_per_unit REAL NOT NULL CHECK (price_per_unit > 0),
    total_price REAL NOT NULL CHECK (total_price > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed', 'cancelled')),
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    expires_at TEXT
);

-- Create trades table
CREATE TABLE trades (
    id TEXT PRIMARY KEY,
    buy_order_id TEXT REFERENCES orders(id),
    sell_order_id TEXT REFERENCES orders(id),
    buyer_address TEXT NOT NULL,
    seller_address TEXT NOT NULL,
    energy_amount REAL NOT NULL CHECK (energy_amount > 0),
    price_per_unit REAL NOT NULL CHECK (price_per_unit > 0),
    total_price REAL NOT NULL CHECK (total_price > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
    executed_at TEXT DEFAULT (datetime('now')),
    created_at TEXT DEFAULT (datetime('now'))
);

-- Create market statistics table
CREATE TABLE market_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    total_trades INTEGER DEFAULT 0,
    total_volume REAL DEFAULT 0,
    average_price REAL DEFAULT 0,
    highest_price REAL DEFAULT 0,
    lowest_price REAL DEFAULT 0,
    active_buy_orders INTEGER DEFAULT 0,
    active_sell_orders INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
);

-- Create indexes for better performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX idx_api_keys_key_hash ON api_keys(key_hash);
CREATE INDEX idx_prosumers_is_active ON prosumers(is_active);
CREATE INDEX idx_orders_prosumer_address ON orders(prosumer_address);
CREATE INDEX idx_orders_type_status ON orders(order_type, status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_trades_executed_at ON trades(executed_at);
CREATE INDEX idx_trades_buyer_address ON trades(buyer_address);
CREATE INDEX idx_trades_seller_address ON trades(seller_address);
CREATE INDEX idx_trades_status ON trades(status);

-- Insert default admin user
INSERT OR IGNORE INTO users (id, username, email, password_hash, role) VALUES 
('550e8400-e29b-41d4-a716-446655440000', 'admin', 'admin@energy-trading.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewSBY7mfxTJOXJAu', 'admin');
