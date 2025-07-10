use sqlx::{Pool, Sqlite, postgres::Postgres, Row, FromRow, sqlite::SqliteConnectOptions};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use std::str::FromStr;
use serde::{Deserialize, Serialize};

#[derive(Debug, thiserror::Error)]
pub enum DatabaseError {
    #[error("Database error: {0}")]
    SqlxError(#[from] sqlx::Error),
    #[error("Migration error: {0}")]
    MigrateError(#[from] sqlx::migrate::MigrateError),
    #[error("Record not found: {0}")]
    NotFound(String),
    #[error("Validation error: {0}")]
    Validation(String),
}

// Database models
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub username: String,
    pub email: String,
    pub password_hash: String,
    pub role: String,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub last_login: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiKey {
    pub id: Uuid,
    pub user_id: Uuid,
    pub name: String,
    pub key_hash: String,
    pub permissions: Vec<String>,
    pub is_active: bool,
    pub expires_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub last_used: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Prosumer {
    pub address: String,
    pub name: String,
    pub energy_generated: f64,
    pub energy_consumed: f64,
    pub grid_tokens: f64,
    pub watt_tokens: f64,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Order {
    pub id: Uuid,
    pub prosumer_address: String,
    pub order_type: String, // "buy" or "sell"
    pub energy_amount: f64,
    pub price_per_unit: f64,
    pub total_price: f64,
    pub status: String, // "pending", "active", "completed", "cancelled"
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub expires_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Trade {
    pub id: Uuid,
    pub buy_order_id: Uuid,
    pub sell_order_id: Uuid,
    pub buyer_address: String,
    pub seller_address: String,
    pub energy_amount: f64,
    pub price_per_unit: f64,
    pub total_price: f64,
    pub status: String, // "pending", "completed", "failed"
    pub executed_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MarketStats {
    pub total_prosumers: i64,
    pub total_orders: i64,
    pub total_trades: i64,
    pub total_energy_traded: f64,
    pub total_volume: f64,
    pub average_price: f64,
    pub active_buy_orders: i64,
    pub active_sell_orders: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProsumerStats {
    pub address: String,
    pub name: String,
    pub energy_generated: f64,
    pub energy_consumed: f64,
    pub net_energy: f64,
    pub grid_tokens: f64,
    pub watt_tokens: f64,
    pub orders_count: i64,
    pub trades_count: i64,
    pub total_energy_traded: f64,
    pub total_volume: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseStats {
    pub total_users: i64,
    pub total_api_keys: i64,
    pub total_prosumers: i64,
    pub total_orders: i64,
    pub total_trades: i64,
    pub database_size: Option<String>,
}

// Database row types for SQLx
#[derive(FromRow)]
struct ProsumerRow {
    pub address: String,
    pub name: String,
    pub energy_generated: f64,
    pub energy_consumed: f64,
    pub grid_tokens: f64,
    pub watt_tokens: f64,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl From<ProsumerRow> for Prosumer {
    fn from(row: ProsumerRow) -> Self {
        Prosumer {
            address: row.address,
            name: row.name,
            energy_generated: row.energy_generated,
            energy_consumed: row.energy_consumed,
            grid_tokens: row.grid_tokens,
            watt_tokens: row.watt_tokens,
            is_active: row.is_active,
            created_at: row.created_at,
            updated_at: row.updated_at,
        }
    }
}

#[derive(FromRow)]
struct OrderRow {
    pub id: Uuid,
    pub prosumer_address: String,
    pub order_type: String,
    pub energy_amount: f64,
    pub price_per_unit: f64,
    pub total_price: f64,
    pub status: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub expires_at: Option<DateTime<Utc>>,
}

impl From<OrderRow> for Order {
    fn from(row: OrderRow) -> Self {
        Order {
            id: row.id,
            prosumer_address: row.prosumer_address,
            order_type: row.order_type,
            energy_amount: row.energy_amount,
            price_per_unit: row.price_per_unit,
            total_price: row.total_price,
            status: row.status,
            created_at: row.created_at,
            updated_at: row.updated_at,
            expires_at: row.expires_at,
        }
    }
}

#[derive(FromRow)]
struct TradeRow {
    pub id: Uuid,
    pub buy_order_id: Uuid,
    pub sell_order_id: Uuid,
    pub buyer_address: String,
    pub seller_address: String,
    pub energy_amount: f64,
    pub price_per_unit: f64,
    pub total_price: f64,
    pub status: String,
    pub executed_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

impl From<TradeRow> for Trade {
    fn from(row: TradeRow) -> Self {
        Trade {
            id: row.id,
            buy_order_id: row.buy_order_id,
            sell_order_id: row.sell_order_id,
            buyer_address: row.buyer_address,
            seller_address: row.seller_address,
            energy_amount: row.energy_amount,
            price_per_unit: row.price_per_unit,
            total_price: row.total_price,
            status: row.status,
            executed_at: row.executed_at,
            created_at: row.created_at,
        }
    }
}

// Database service with support for both PostgreSQL and SQLite
pub enum DatabasePool {
    Postgres(Pool<Postgres>),
    Sqlite(Pool<Sqlite>),
}

pub struct DatabaseService {
    pool: DatabasePool,
}

impl DatabaseService {
    pub async fn new(database_url: &str) -> Result<Self, DatabaseError> {
        let pool = if database_url.starts_with("postgres://") || database_url.starts_with("postgresql://") {
            DatabasePool::Postgres(Pool::<Postgres>::connect(database_url).await?)
        } else {
            // For SQLite, use custom connection options to create database if missing
            let sqlite_options = SqliteConnectOptions::from_str(database_url)?
                .create_if_missing(true);
            DatabasePool::Sqlite(Pool::<Sqlite>::connect_with(sqlite_options).await?)
        };
        
        Ok(Self { pool })
    }

    pub async fn run_migrations(&self) -> Result<(), DatabaseError> {
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                sqlx::migrate!("./migrations").run(pool).await?;
            }
            DatabasePool::Sqlite(pool) => {
                sqlx::migrate!("./migrations").run(pool).await?;
            }
        }
        Ok(())
    }

    pub async fn create_prosumer(&self, prosumer: Prosumer) -> Result<Prosumer, DatabaseError> {
        let query = r#"
            INSERT INTO prosumers (address, name, energy_generated, energy_consumed, grid_tokens, watt_tokens, is_active, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
        "#;
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query_as::<_, ProsumerRow>(query)
                    .bind(&prosumer.address)
                    .bind(&prosumer.name)
                    .bind(prosumer.energy_generated)
                    .bind(prosumer.energy_consumed)
                    .bind(prosumer.grid_tokens)
                    .bind(prosumer.watt_tokens)
                    .bind(prosumer.is_active)
                    .bind(prosumer.created_at)
                    .bind(prosumer.updated_at)
                    .fetch_one(pool)
                    .await?;
                Ok(row.into())
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query_as::<_, ProsumerRow>(query)
                    .bind(&prosumer.address)
                    .bind(&prosumer.name)
                    .bind(prosumer.energy_generated)
                    .bind(prosumer.energy_consumed)
                    .bind(prosumer.grid_tokens)
                    .bind(prosumer.watt_tokens)
                    .bind(prosumer.is_active)
                    .bind(prosumer.created_at)
                    .bind(prosumer.updated_at)
                    .fetch_one(pool)
                    .await?;
                Ok(row.into())
            }
        }
    }

    pub async fn get_prosumer(&self, address: &str) -> Result<Prosumer, DatabaseError> {
        let query = "SELECT * FROM prosumers WHERE address = $1";
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query_as::<_, ProsumerRow>(query)
                    .bind(address)
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Prosumer '{}' not found", address))),
                }
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query_as::<_, ProsumerRow>(query)
                    .bind(address)
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Prosumer '{}' not found", address))),
                }
            }
        }
    }

    pub async fn get_prosumers(&self, page: u32, limit: u32) -> Result<Vec<Prosumer>, DatabaseError> {
        let offset = (page - 1) * limit;
        let query = "SELECT * FROM prosumers ORDER BY created_at DESC LIMIT $1 OFFSET $2";
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let rows = sqlx::query_as::<_, ProsumerRow>(query)
                    .bind(limit as i64)
                    .bind(offset as i64)
                    .fetch_all(pool)
                    .await?;
                Ok(rows.into_iter().map(|row| row.into()).collect())
            }
            DatabasePool::Sqlite(pool) => {
                let rows = sqlx::query_as::<_, ProsumerRow>(query)
                    .bind(limit as i64)
                    .bind(offset as i64)
                    .fetch_all(pool)
                    .await?;
                Ok(rows.into_iter().map(|row| row.into()).collect())
            }
        }
    }

    pub async fn update_prosumer(&self, address: &str, name: Option<String>, energy_generated: Option<f64>, energy_consumed: Option<f64>) -> Result<Prosumer, DatabaseError> {
        let query = r#"
            UPDATE prosumers 
            SET name = COALESCE($2, name),
                energy_generated = COALESCE($3, energy_generated),
                energy_consumed = COALESCE($4, energy_consumed),
                updated_at = $5
            WHERE address = $1
            RETURNING *
        "#;
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query_as::<_, ProsumerRow>(query)
                    .bind(address)
                    .bind(name.as_deref())
                    .bind(energy_generated)
                    .bind(energy_consumed)
                    .bind(Utc::now())
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Prosumer '{}' not found", address))),
                }
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query_as::<_, ProsumerRow>(query)
                    .bind(address)
                    .bind(name.as_deref())
                    .bind(energy_generated)
                    .bind(energy_consumed)
                    .bind(Utc::now())
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Prosumer '{}' not found", address))),
                }
            }
        }
    }

    pub async fn create_order(&self, order: Order) -> Result<Order, DatabaseError> {
        let query = r#"
            INSERT INTO orders (id, prosumer_address, order_type, energy_amount, price_per_unit, total_price, status, created_at, updated_at, expires_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING *
        "#;
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query_as::<_, OrderRow>(query)
                    .bind(order.id)
                    .bind(&order.prosumer_address)
                    .bind(&order.order_type)
                    .bind(order.energy_amount)
                    .bind(order.price_per_unit)
                    .bind(order.total_price)
                    .bind(&order.status)
                    .bind(order.created_at)
                    .bind(order.updated_at)
                    .bind(order.expires_at)
                    .fetch_one(pool)
                    .await?;
                Ok(row.into())
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query_as::<_, OrderRow>(query)
                    .bind(order.id)
                    .bind(&order.prosumer_address)
                    .bind(&order.order_type)
                    .bind(order.energy_amount)
                    .bind(order.price_per_unit)
                    .bind(order.total_price)
                    .bind(&order.status)
                    .bind(order.created_at)
                    .bind(order.updated_at)
                    .bind(order.expires_at)
                    .fetch_one(pool)
                    .await?;
                Ok(row.into())
            }
        }
    }

    pub async fn get_order(&self, id: Uuid) -> Result<Order, DatabaseError> {
        let query = "SELECT * FROM orders WHERE id = $1";
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query_as::<_, OrderRow>(query)
                    .bind(id)
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Order '{}' not found", id))),
                }
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query_as::<_, OrderRow>(query)
                    .bind(id)
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Order '{}' not found", id))),
                }
            }
        }
    }

    pub async fn get_orders(&self, page: u32, limit: u32, status: Option<String>, order_type: Option<String>, prosumer_address: Option<String>) -> Result<Vec<Order>, DatabaseError> {
        let offset = (page - 1) * limit;
        let mut query = "SELECT * FROM orders WHERE 1=1".to_string();
        let mut bind_count = 1;
        
        if status.is_some() {
            query.push_str(&format!(" AND status = ${}", bind_count));
            bind_count += 1;
        }
        if order_type.is_some() {
            query.push_str(&format!(" AND order_type = ${}", bind_count));
            bind_count += 1;
        }
        if prosumer_address.is_some() {
            query.push_str(&format!(" AND prosumer_address = ${}", bind_count));
            bind_count += 1;
        }
        
        query.push_str(&format!(" ORDER BY created_at DESC LIMIT ${} OFFSET ${}", bind_count, bind_count + 1));
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let mut q = sqlx::query_as::<_, OrderRow>(&query);
                if let Some(ref s) = status {
                    q = q.bind(s);
                }
                if let Some(ref ot) = order_type {
                    q = q.bind(ot);
                }
                if let Some(ref pa) = prosumer_address {
                    q = q.bind(pa);
                }
                q = q.bind(limit as i64).bind(offset as i64);
                let rows = q.fetch_all(pool).await?;
                Ok(rows.into_iter().map(|row| row.into()).collect())
            }
            DatabasePool::Sqlite(pool) => {
                let mut q = sqlx::query_as::<_, OrderRow>(&query);
                if let Some(ref s) = status {
                    q = q.bind(s);
                }
                if let Some(ref ot) = order_type {
                    q = q.bind(ot);
                }
                if let Some(ref pa) = prosumer_address {
                    q = q.bind(pa);
                }
                q = q.bind(limit as i64).bind(offset as i64);
                let rows = q.fetch_all(pool).await?;
                Ok(rows.into_iter().map(|row| row.into()).collect())
            }
        }
    }

    pub async fn update_order(&self, id: Uuid, status: Option<String>, energy_amount: Option<f64>, price_per_unit: Option<f64>) -> Result<Order, DatabaseError> {
        let query = r#"
            UPDATE orders 
            SET status = COALESCE($2, status),
                energy_amount = COALESCE($3, energy_amount),
                price_per_unit = COALESCE($4, price_per_unit),
                total_price = COALESCE($3 * $4, total_price),
                updated_at = $5
            WHERE id = $1
            RETURNING *
        "#;
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query_as::<_, OrderRow>(query)
                    .bind(id)
                    .bind(status.as_deref())
                    .bind(energy_amount)
                    .bind(price_per_unit)
                    .bind(Utc::now())
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Order '{}' not found", id))),
                }
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query_as::<_, OrderRow>(query)
                    .bind(id)
                    .bind(status.as_deref())
                    .bind(energy_amount)
                    .bind(price_per_unit)
                    .bind(Utc::now())
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Order '{}' not found", id))),
                }
            }
        }
    }

    pub async fn cancel_order(&self, id: Uuid) -> Result<Order, DatabaseError> {
        let query = r#"
            UPDATE orders 
            SET status = 'cancelled',
                updated_at = $2
            WHERE id = $1
            RETURNING *
        "#;
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query_as::<_, OrderRow>(query)
                    .bind(id)
                    .bind(Utc::now())
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Order '{}' not found", id))),
                }
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query_as::<_, OrderRow>(query)
                    .bind(id)
                    .bind(Utc::now())
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Order '{}' not found", id))),
                }
            }
        }
    }

    pub async fn create_trade(&self, trade: Trade) -> Result<Trade, DatabaseError> {
        let query = r#"
            INSERT INTO trades (id, buy_order_id, sell_order_id, buyer_address, seller_address, energy_amount, price_per_unit, total_price, status, executed_at, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            RETURNING *
        "#;
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query_as::<_, TradeRow>(query)
                    .bind(trade.id)
                    .bind(trade.buy_order_id)
                    .bind(trade.sell_order_id)
                    .bind(&trade.buyer_address)
                    .bind(&trade.seller_address)
                    .bind(trade.energy_amount)
                    .bind(trade.price_per_unit)
                    .bind(trade.total_price)
                    .bind(&trade.status)
                    .bind(trade.executed_at)
                    .bind(trade.created_at)
                    .fetch_one(pool)
                    .await?;
                Ok(row.into())
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query_as::<_, TradeRow>(query)
                    .bind(trade.id)
                    .bind(trade.buy_order_id)
                    .bind(trade.sell_order_id)
                    .bind(&trade.buyer_address)
                    .bind(&trade.seller_address)
                    .bind(trade.energy_amount)
                    .bind(trade.price_per_unit)
                    .bind(trade.total_price)
                    .bind(&trade.status)
                    .bind(trade.executed_at)
                    .bind(trade.created_at)
                    .fetch_one(pool)
                    .await?;
                Ok(row.into())
            }
        }
    }

    pub async fn get_trade(&self, id: Uuid) -> Result<Trade, DatabaseError> {
        let query = "SELECT * FROM trades WHERE id = $1";
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query_as::<_, TradeRow>(query)
                    .bind(id)
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Trade '{}' not found", id))),
                }
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query_as::<_, TradeRow>(query)
                    .bind(id)
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(row.into()),
                    None => Err(DatabaseError::NotFound(format!("Trade '{}' not found", id))),
                }
            }
        }
    }

    pub async fn get_trades(&self, page: u32, limit: u32) -> Result<Vec<Trade>, DatabaseError> {
        let offset = (page - 1) * limit;
        let query = "SELECT * FROM trades ORDER BY created_at DESC LIMIT $1 OFFSET $2";
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let rows = sqlx::query_as::<_, TradeRow>(query)
                    .bind(limit as i64)
                    .bind(offset as i64)
                    .fetch_all(pool)
                    .await?;
                Ok(rows.into_iter().map(|row| row.into()).collect())
            }
            DatabasePool::Sqlite(pool) => {
                let rows = sqlx::query_as::<_, TradeRow>(query)
                    .bind(limit as i64)
                    .bind(offset as i64)
                    .fetch_all(pool)
                    .await?;
                Ok(rows.into_iter().map(|row| row.into()).collect())
            }
        }
    }

    pub async fn execute_trade(&self, trade: Trade) -> Result<Trade, DatabaseError> {
        // First create the trade
        let created_trade = self.create_trade(trade).await?;
        
        // Then update the associated orders to completed
        let _buy_order = self.update_order(created_trade.buy_order_id, Some("completed".to_string()), None, None).await?;
        let _sell_order = self.update_order(created_trade.sell_order_id, Some("completed".to_string()), None, None).await?;
        
        Ok(created_trade)
    }

    pub async fn get_market_stats(&self) -> Result<MarketStats, DatabaseError> {
        let query = r#"
            SELECT 
                (SELECT COUNT(*) FROM prosumers) as total_prosumers,
                (SELECT COUNT(*) FROM orders) as total_orders,
                (SELECT COUNT(*) FROM trades) as total_trades,
                (SELECT COALESCE(SUM(CAST(energy_amount AS REAL)), 0.0) FROM trades WHERE status = 'completed') as total_energy_traded,
                (SELECT COALESCE(SUM(CAST(total_price AS REAL)), 0.0) FROM trades WHERE status = 'completed') as total_volume,
                (SELECT COALESCE(AVG(CAST(price_per_unit AS REAL)), 0.0) FROM trades WHERE status = 'completed') as average_price,
                (SELECT COUNT(*) FROM orders WHERE status = 'active' AND order_type = 'buy') as active_buy_orders,
                (SELECT COUNT(*) FROM orders WHERE status = 'active' AND order_type = 'sell') as active_sell_orders
        "#;
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query(query).fetch_one(pool).await?;
                Ok(MarketStats {
                    total_prosumers: row.get::<i64, _>("total_prosumers"),
                    total_orders: row.get::<i64, _>("total_orders"),
                    total_trades: row.get::<i64, _>("total_trades"),
                    total_energy_traded: row.get::<f64, _>("total_energy_traded"),
                    total_volume: row.get::<f64, _>("total_volume"),
                    average_price: row.get::<f64, _>("average_price"),
                    active_buy_orders: row.get::<i64, _>("active_buy_orders"),
                    active_sell_orders: row.get::<i64, _>("active_sell_orders"),
                })
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query(query).fetch_one(pool).await?;
                Ok(MarketStats {
                    total_prosumers: row.get::<i64, _>("total_prosumers"),
                    total_orders: row.get::<i64, _>("total_orders"),
                    total_trades: row.get::<i64, _>("total_trades"),
                    total_energy_traded: row.get::<f64, _>("total_energy_traded"),
                    total_volume: row.get::<f64, _>("total_volume"),
                    average_price: row.get::<f64, _>("average_price"),
                    active_buy_orders: row.get::<i64, _>("active_buy_orders"),
                    active_sell_orders: row.get::<i64, _>("active_sell_orders"),
                })
            }
        }
    }

    pub async fn get_prosumer_stats(&self, address: &str) -> Result<ProsumerStats, DatabaseError> {
        let query = r#"
            SELECT 
                p.address,
                p.name,
                p.energy_generated,
                p.energy_consumed,
                (p.energy_generated - p.energy_consumed) as net_energy,
                p.grid_tokens,
                p.watt_tokens,
                (SELECT COUNT(*) FROM orders WHERE prosumer_address = p.address) as orders_count,
                (SELECT COUNT(*) FROM trades WHERE buyer_address = p.address OR seller_address = p.address) as trades_count,
                (SELECT COALESCE(SUM(energy_amount), 0) FROM trades WHERE (buyer_address = p.address OR seller_address = p.address) AND status = 'completed') as total_energy_traded,
                (SELECT COALESCE(SUM(total_price), 0) FROM trades WHERE (buyer_address = p.address OR seller_address = p.address) AND status = 'completed') as total_volume
            FROM prosumers p
            WHERE p.address = $1
        "#;
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query(query)
                    .bind(address)
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(ProsumerStats {
                        address: row.get::<String, _>("address"),
                        name: row.get::<String, _>("name"),
                        energy_generated: row.get::<f64, _>("energy_generated"),
                        energy_consumed: row.get::<f64, _>("energy_consumed"),
                        net_energy: row.get::<f64, _>("net_energy"),
                        grid_tokens: row.get::<f64, _>("grid_tokens"),
                        watt_tokens: row.get::<f64, _>("watt_tokens"),
                        orders_count: row.get::<i64, _>("orders_count"),
                        trades_count: row.get::<i64, _>("trades_count"),
                        total_energy_traded: row.get::<f64, _>("total_energy_traded"),
                        total_volume: row.get::<f64, _>("total_volume"),
                    }),
                    None => Err(DatabaseError::NotFound(format!("Prosumer '{}' not found", address))),
                }
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query(query)
                    .bind(address)
                    .fetch_optional(pool)
                    .await?;
                match row {
                    Some(row) => Ok(ProsumerStats {
                        address: row.get::<String, _>("address"),
                        name: row.get::<String, _>("name"),
                        energy_generated: row.get::<f64, _>("energy_generated"),
                        energy_consumed: row.get::<f64, _>("energy_consumed"),
                        net_energy: row.get::<f64, _>("net_energy"),
                        grid_tokens: row.get::<f64, _>("grid_tokens"),
                        watt_tokens: row.get::<f64, _>("watt_tokens"),
                        orders_count: row.get::<i64, _>("orders_count"),
                        trades_count: row.get::<i64, _>("trades_count"),
                        total_energy_traded: row.get::<f64, _>("total_energy_traded"),
                        total_volume: row.get::<f64, _>("total_volume"),
                    }),
                    None => Err(DatabaseError::NotFound(format!("Prosumer '{}' not found", address))),
                }
            }
        }
    }

    pub async fn get_stats(&self) -> Result<DatabaseStats, DatabaseError> {
        let query = r#"
            SELECT 
                (SELECT COUNT(*) FROM prosumers) as total_prosumers,
                (SELECT COUNT(*) FROM orders) as total_orders,
                (SELECT COUNT(*) FROM trades) as total_trades
        "#;
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let row = sqlx::query(query).fetch_one(pool).await?;
                Ok(DatabaseStats {
                    total_users: 0, // We don't have users table yet
                    total_api_keys: 0, // We don't have api_keys table yet
                    total_prosumers: row.get::<i64, _>("total_prosumers"),
                    total_orders: row.get::<i64, _>("total_orders"),
                    total_trades: row.get::<i64, _>("total_trades"),
                    database_size: None, // Would need platform-specific queries
                })
            }
            DatabasePool::Sqlite(pool) => {
                let row = sqlx::query(query).fetch_one(pool).await?;
                Ok(DatabaseStats {
                    total_users: 0, // We don't have users table yet
                    total_api_keys: 0, // We don't have api_keys table yet
                    total_prosumers: row.get::<i64, _>("total_prosumers"),
                    total_orders: row.get::<i64, _>("total_orders"),
                    total_trades: row.get::<i64, _>("total_trades"),
                    database_size: None, // Would need platform-specific queries
                })
            }
        }
    }

    pub async fn transfer_tokens(&self, from_address: &str, to_address: &str, amount: f64, token_type: &str) -> Result<String, DatabaseError> {
        // Start a transaction
        let transaction_id = Uuid::new_v4();
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let mut tx = pool.begin().await?;
                
                // Check if sender has enough tokens
                let sender = sqlx::query_as::<_, ProsumerRow>("SELECT * FROM prosumers WHERE address = $1")
                    .bind(from_address)
                    .fetch_optional(&mut *tx)
                    .await?;
                
                if let Some(sender) = sender {
                    let current_balance = match token_type {
                        "grid_tokens" => sender.grid_tokens,
                        "watt_tokens" => sender.watt_tokens,
                        _ => return Err(DatabaseError::Validation("Invalid token type".to_string())),
                    };
                    
                    if current_balance < amount {
                        return Err(DatabaseError::Validation("Insufficient tokens".to_string()));
                    }
                    
                    // Deduct from sender
                    let query = match token_type {
                        "grid_tokens" => "UPDATE prosumers SET grid_tokens = grid_tokens - $1, updated_at = $2 WHERE address = $3",
                        "watt_tokens" => "UPDATE prosumers SET watt_tokens = watt_tokens - $1, updated_at = $2 WHERE address = $3",
                        _ => unreachable!(),
                    };
                    
                    sqlx::query(query)
                        .bind(amount)
                        .bind(Utc::now())
                        .bind(from_address)
                        .execute(&mut *tx)
                        .await?;
                    
                    // Add to recipient
                    let query = match token_type {
                        "grid_tokens" => "UPDATE prosumers SET grid_tokens = grid_tokens + $1, updated_at = $2 WHERE address = $3",
                        "watt_tokens" => "UPDATE prosumers SET watt_tokens = watt_tokens + $1, updated_at = $2 WHERE address = $3",
                        _ => unreachable!(),
                    };
                    
                    sqlx::query(query)
                        .bind(amount)
                        .bind(Utc::now())
                        .bind(to_address)
                        .execute(&mut *tx)
                        .await?;
                    
                    tx.commit().await?;
                    Ok(transaction_id.to_string())
                } else {
                    Err(DatabaseError::NotFound(format!("Prosumer '{}' not found", from_address)))
                }
            }
            DatabasePool::Sqlite(pool) => {
                let mut tx = pool.begin().await?;
                
                // Check if sender has enough tokens
                let sender = sqlx::query_as::<_, ProsumerRow>("SELECT * FROM prosumers WHERE address = $1")
                    .bind(from_address)
                    .fetch_optional(&mut *tx)
                    .await?;
                
                if let Some(sender) = sender {
                    let current_balance = match token_type {
                        "grid_tokens" => sender.grid_tokens,
                        "watt_tokens" => sender.watt_tokens,
                        _ => return Err(DatabaseError::Validation("Invalid token type".to_string())),
                    };
                    
                    if current_balance < amount {
                        return Err(DatabaseError::Validation("Insufficient tokens".to_string()));
                    }
                    
                    // Deduct from sender
                    let query = match token_type {
                        "grid_tokens" => "UPDATE prosumers SET grid_tokens = grid_tokens - $1, updated_at = $2 WHERE address = $3",
                        "watt_tokens" => "UPDATE prosumers SET watt_tokens = watt_tokens - $1, updated_at = $2 WHERE address = $3",
                        _ => unreachable!(),
                    };
                    
                    sqlx::query(query)
                        .bind(amount)
                        .bind(Utc::now())
                        .bind(from_address)
                        .execute(&mut *tx)
                        .await?;
                    
                    // Add to recipient
                    let query = match token_type {
                        "grid_tokens" => "UPDATE prosumers SET grid_tokens = grid_tokens + $1, updated_at = $2 WHERE address = $3",
                        "watt_tokens" => "UPDATE prosumers SET watt_tokens = watt_tokens + $1, updated_at = $2 WHERE address = $3",
                        _ => unreachable!(),
                    };
                    
                    sqlx::query(query)
                        .bind(amount)
                        .bind(Utc::now())
                        .bind(to_address)
                        .execute(&mut *tx)
                        .await?;
                    
                    tx.commit().await?;
                    Ok(transaction_id.to_string())
                } else {
                    Err(DatabaseError::NotFound(format!("Prosumer '{}' not found", from_address)))
                }
            }
        }
    }

    pub async fn match_orders(&self) -> Result<Vec<Trade>, DatabaseError> {
        // Simple order matching algorithm
        let query = r#"
            SELECT b.id as buy_id, b.prosumer_address as buyer_address, b.energy_amount as buy_amount, b.price_per_unit as buy_price,
                   s.id as sell_id, s.prosumer_address as seller_address, s.energy_amount as sell_amount, s.price_per_unit as sell_price
            FROM orders b
            JOIN orders s ON b.order_type = 'buy' AND s.order_type = 'sell' 
                          AND b.price_per_unit >= s.price_per_unit
                          AND b.status = 'active' AND s.status = 'active'
            ORDER BY b.created_at, s.created_at
            LIMIT 10
        "#;
        
        let mut trades = Vec::new();
        
        match &self.pool {
            DatabasePool::Postgres(pool) => {
                let rows = sqlx::query(query).fetch_all(pool).await?;
                
                for row in rows {
                    let buy_id: Uuid = row.get("buy_id");
                    let sell_id: Uuid = row.get("sell_id");
                    let buyer_address: String = row.get("buyer_address");
                    let seller_address: String = row.get("seller_address");
                    let buy_amount: f64 = row.get("buy_amount");
                    let sell_amount: f64 = row.get("sell_amount");
                    let buy_price: f64 = row.get("buy_price");
                    let sell_price: f64 = row.get("sell_price");
                    
                    // Match at the lower price (seller's price)
                    let trade_price = sell_price;
                    let trade_amount = buy_amount.min(sell_amount);
                    
                    let trade = Trade {
                        id: Uuid::new_v4(),
                        buy_order_id: buy_id,
                        sell_order_id: sell_id,
                        buyer_address,
                        seller_address,
                        energy_amount: trade_amount,
                        price_per_unit: trade_price,
                        total_price: trade_amount * trade_price,
                        status: "pending".to_string(),
                        executed_at: Utc::now(),
                        created_at: Utc::now(),
                    };
                    
                    trades.push(trade);
                }
            }
            DatabasePool::Sqlite(pool) => {
                let rows = sqlx::query(query).fetch_all(pool).await?;
                
                for row in rows {
                    let buy_id: Uuid = row.get("buy_id");
                    let sell_id: Uuid = row.get("sell_id");
                    let buyer_address: String = row.get("buyer_address");
                    let seller_address: String = row.get("seller_address");
                    let buy_amount: f64 = row.get("buy_amount");
                    let sell_amount: f64 = row.get("sell_amount");
                    let buy_price: f64 = row.get("buy_price");
                    let sell_price: f64 = row.get("sell_price");
                    
                    // Match at the lower price (seller's price)
                    let trade_price = sell_price;
                    let trade_amount = buy_amount.min(sell_amount);
                    
                    let trade = Trade {
                        id: Uuid::new_v4(),
                        buy_order_id: buy_id,
                        sell_order_id: sell_id,
                        buyer_address,
                        seller_address,
                        energy_amount: trade_amount,
                        price_per_unit: trade_price,
                        total_price: trade_amount * trade_price,
                        status: "pending".to_string(),
                        executed_at: Utc::now(),
                        created_at: Utc::now(),
                    };
                    
                    trades.push(trade);
                }
            }
        }
        
        Ok(trades)
    }
}
