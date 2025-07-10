use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

// API Request/Response Models

#[derive(Debug, Serialize, Deserialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub message: String,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            message: "Success".to_string(),
            timestamp: chrono::Utc::now(),
        }
    }

    pub fn error(message: String) -> Self {
        Self {
            success: false,
            data: None,
            message,
            timestamp: chrono::Utc::now(),
        }
    }
}

// Prosumer API Models
#[derive(Debug, Serialize, Deserialize)]
pub struct CreateProsumerRequest {
    pub address: String,
    pub name: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateProsumerRequest {
    pub name: Option<String>,
    pub energy_generated: Option<f64>,
    pub energy_consumed: Option<f64>,
}

// Order API Models
#[derive(Debug, Serialize, Deserialize)]
pub struct CreateOrderRequest {
    pub prosumer_address: String,
    pub order_type: String, // "buy" or "sell"
    pub energy_amount: f64,
    pub price_per_unit: f64,
    pub expires_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateOrderRequest {
    pub status: Option<String>,
    pub energy_amount: Option<f64>,
    pub price_per_unit: Option<f64>,
}

// Trade API Models
#[derive(Debug, Serialize, Deserialize)]
pub struct ExecuteTradeRequest {
    pub buy_order_id: Uuid,
    pub sell_order_id: Uuid,
    pub price_per_unit: Option<f64>,
}

// Token transfer API Models
#[derive(Debug, Serialize, Deserialize)]
pub struct TransferTokensRequest {
    pub from_address: String,
    pub to_address: String,
    pub amount: f64,
    pub token_type: String, // "grid_tokens" or "watt_tokens"
}
// Legacy API Models (for backward compatibility)
#[derive(Debug, Serialize, Deserialize)]
pub struct CreateAccountRequest {
    pub address: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TransferRequest {
    pub from: String,
    pub to: String,
    pub amount: f64,
    pub token_type: String, // "grid" or "watt"
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StakeRequest {
    pub address: String,
    pub amount: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GovernanceProposalRequest {
    pub title: String,
    pub description: String,
    pub proposer: String,
    pub voting_duration_hours: u64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct VoteRequest {
    pub proposal_id: String,
    pub voter: String,
    pub vote: bool, // true for yes, false for no
    pub stake_amount: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CancelOrderRequest {
    pub order_id: String,
    pub trader_address: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProsumerRequest {
    pub address: String,
    pub name: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EnergyUpdateRequest {
    pub address: String,
    pub amount: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct MarketStatistics {
    pub total_buy_orders: usize,
    pub total_sell_orders: usize,
    pub total_trades: usize,
    pub average_price: f64,
    pub total_volume: f64,
    pub grid_fee_rate: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProsumerInfo {
    pub address: String,
    pub name: String,
    pub energy_generated: f64,
    pub energy_consumed: f64,
    pub net_energy: f64,
    pub grid_tokens: f64,
    pub watt_tokens: f64,
}

// Error Types
#[derive(Debug, Serialize, Deserialize)]
pub struct ApiError {
    pub code: u16,
    pub message: String,
}

impl From<String> for ApiError {
    fn from(message: String) -> Self {
        Self {
            code: 400,
            message,
        }
    }
}

impl From<&str> for ApiError {
    fn from(message: &str) -> Self {
        Self {
            code: 400,
            message: message.to_string(),
        }
    }
}