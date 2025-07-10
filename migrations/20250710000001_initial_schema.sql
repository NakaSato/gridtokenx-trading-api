-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'trader',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE
);

-- Create API keys table
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    key_hash VARCHAR(255) NOT NULL,
    permissions TEXT[] DEFAULT ARRAY['read'],
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used TIMESTAMP WITH TIME ZONE
);

-- Create prosumers table
CREATE TABLE prosumers (
    address VARCHAR(100) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    energy_generated DECIMAL(15,2) DEFAULT 0,
    energy_consumed DECIMAL(15,2) DEFAULT 0,
    grid_tokens DECIMAL(15,2) DEFAULT 0,
    watt_tokens DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create energy orders table
CREATE TABLE energy_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trader_address VARCHAR(100) NOT NULL,
    order_type VARCHAR(10) NOT NULL CHECK (order_type IN ('buy', 'sell')),
    energy_amount DECIMAL(15,2) NOT NULL CHECK (energy_amount > 0),
    price_per_kwh DECIMAL(10,4) NOT NULL CHECK (price_per_kwh > 0),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create energy trades table
CREATE TABLE energy_trades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buy_order_id UUID REFERENCES energy_orders(id),
    sell_order_id UUID REFERENCES energy_orders(id),
    buyer_address VARCHAR(100) NOT NULL,
    seller_address VARCHAR(100) NOT NULL,
    energy_amount DECIMAL(15,2) NOT NULL CHECK (energy_amount > 0),
    price_per_kwh DECIMAL(10,4) NOT NULL CHECK (price_per_kwh > 0),
    total_price DECIMAL(15,2) NOT NULL CHECK (total_price > 0),
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create market statistics table
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX idx_api_keys_key_hash ON api_keys(key_hash);
CREATE INDEX idx_energy_orders_trader_address ON energy_orders(trader_address);
CREATE INDEX idx_energy_orders_type_active ON energy_orders(order_type, is_active);
CREATE INDEX idx_energy_trades_executed_at ON energy_trades(executed_at);
CREATE INDEX idx_energy_trades_buyer_address ON energy_trades(buyer_address);
CREATE INDEX idx_energy_trades_seller_address ON energy_trades(seller_address);

-- Insert default admin user
INSERT INTO users (id, username, email, password_hash, role) VALUES 
('550e8400-e29b-41d4-a716-446655440000', 'admin', 'admin@energy-trading.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewSBY7mfxTJOXJAu', 'admin')
ON CONFLICT (username) DO NOTHING;
