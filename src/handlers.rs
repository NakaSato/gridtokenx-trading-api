use std::sync::Arc;

use ntex::web::{self, HttpResponse};
use ntex::web::types::State;
use serde_json::json;
use uuid::Uuid;
use chrono::Utc;

use crate::database::{DatabaseService, Prosumer, Order, Trade};
use crate::models::*;

// Root handler - returns API information
pub async fn root() -> Result<HttpResponse, ntex::web::Error> {
    Ok(HttpResponse::Ok().json(&json!({
        "name": "Energy Trading API",
        "version": "1.0.0",
        "description": "API for energy trading between prosumers",
    })))
}

// Health check endpoint
pub async fn health_check() -> Result<HttpResponse, ntex::web::Error> {
    Ok(HttpResponse::Ok().json(&json!({
        "status": "healthy",
    })))
}

// Prosumer handlers
pub async fn create_prosumer(
    state: State<Arc<DatabaseService>>,
    body: web::types::Json<CreateProsumerRequest>,
) -> Result<HttpResponse, ntex::web::Error> {
    let prosumer = Prosumer {
        address: body.address.clone(),
        name: body.name.clone(),
        energy_generated: 0.0,
        energy_consumed: 0.0,
        grid_tokens: 0.0,
        watt_tokens: 0.0,
        is_active: true,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };
    
    match state.create_prosumer(prosumer).await {
        Ok(prosumer) => Ok(HttpResponse::Created().json(&prosumer)),
        Err(e) => Ok(HttpResponse::BadRequest().json(&json!({
            "error": format!("Failed to create prosumer: {}", e)
        })))
    }
}

pub async fn get_prosumer(
    state: State<Arc<DatabaseService>>,
    address: web::types::Path<String>,
) -> Result<HttpResponse, ntex::web::Error> {
    let address = address.into_inner();
    match state.get_prosumer(&address).await {
        Ok(prosumer) => Ok(HttpResponse::Ok().json(&prosumer)),
        Err(e) => {
            if e.to_string().contains("not found") {
                Ok(HttpResponse::NotFound().json(&json!({
                    "error": format!("Prosumer with address {} not found", address)
                })))
            } else {
                Ok(HttpResponse::InternalServerError().json(&json!({
                    "error": format!("Failed to get prosumer: {}", e)
                })))
            }
        }
    }
}

pub async fn get_all_prosumers(
    state: State<Arc<DatabaseService>>,
) -> Result<HttpResponse, ntex::web::Error> {
    match state.get_prosumers(0, 100).await {
        Ok(prosumers) => Ok(HttpResponse::Ok().json(&prosumers)),
        Err(e) => Ok(HttpResponse::InternalServerError().json(&json!({
            "error": format!("Failed to get prosumers: {}", e)
        })))
    }
}

pub async fn update_prosumer(
    state: State<Arc<DatabaseService>>,
    address: web::types::Path<String>,
    body: web::types::Json<UpdateProsumerRequest>,
) -> Result<HttpResponse, ntex::web::Error> {
    let address = address.into_inner();
    match state.update_prosumer(&address, body.name.clone(), body.energy_generated, body.energy_consumed).await {
        Ok(prosumer) => Ok(HttpResponse::Ok().json(&prosumer)),
        Err(e) => {
            if e.to_string().contains("not found") {
                Ok(HttpResponse::NotFound().json(&json!({
                    "error": format!("Prosumer with address {} not found", address)
                })))
            } else {
                Ok(HttpResponse::InternalServerError().json(&json!({
                    "error": format!("Failed to update prosumer: {}", e)
                })))
            }
        }
    }
}

// Energy order handlers
pub async fn create_energy_order(
    state: State<Arc<DatabaseService>>,
    body: web::types::Json<CreateOrderRequest>,
) -> Result<HttpResponse, ntex::web::Error> {
    let order = Order {
        id: Uuid::new_v4(),
        prosumer_address: body.prosumer_address.clone(),
        order_type: body.order_type.clone(),
        energy_amount: body.energy_amount,
        price_per_unit: body.price_per_unit,
        total_price: body.energy_amount * body.price_per_unit,
        status: "active".to_string(),
        created_at: Utc::now(),
        updated_at: Utc::now(),
        expires_at: body.expires_at,
    };
    
    match state.create_order(order).await {
        Ok(order) => Ok(HttpResponse::Created().json(&order)),
        Err(e) => Ok(HttpResponse::BadRequest().json(&json!({
            "error": format!("Failed to create order: {}", e)
        })))
    }
}

pub async fn get_energy_order(
    state: State<Arc<DatabaseService>>,
    order_id: web::types::Path<String>,
) -> Result<HttpResponse, ntex::web::Error> {
    let order_id_str = order_id.into_inner();
    let order_id = match Uuid::parse_str(&order_id_str) {
        Ok(id) => id,
        Err(_) => return Ok(HttpResponse::BadRequest().json(&json!({
            "error": "Invalid order ID format"
        })))
    };
    
    match state.get_order(order_id).await {
        Ok(order) => Ok(HttpResponse::Ok().json(&order)),
        Err(e) => {
            if e.to_string().contains("not found") {
                Ok(HttpResponse::NotFound().json(&json!({
                    "error": format!("Order with ID {} not found", order_id)
                })))
            } else {
                Ok(HttpResponse::InternalServerError().json(&json!({
                    "error": format!("Failed to get order: {}", e)
                })))
            }
        }
    }
}

pub async fn get_all_energy_orders(
    state: State<Arc<DatabaseService>>,
) -> Result<HttpResponse, ntex::web::Error> {
    match state.get_orders(0, 100, None, None, None).await {
        Ok(orders) => Ok(HttpResponse::Ok().json(&orders)),
        Err(e) => Ok(HttpResponse::InternalServerError().json(&json!({
            "error": format!("Failed to get orders: {}", e)
        })))
    }
}

pub async fn update_energy_order(
    state: State<Arc<DatabaseService>>,
    order_id: web::types::Path<String>,
    body: web::types::Json<UpdateOrderRequest>,
) -> Result<HttpResponse, ntex::web::Error> {
    let order_id_str = order_id.into_inner();
    let order_id = match Uuid::parse_str(&order_id_str) {
        Ok(id) => id,
        Err(_) => return Ok(HttpResponse::BadRequest().json(&json!({
            "error": "Invalid order ID format"
        })))
    };
    
    match state.update_order(order_id, body.status.clone(), body.energy_amount, body.price_per_unit).await {
        Ok(order) => Ok(HttpResponse::Ok().json(&order)),
        Err(e) => {
            if e.to_string().contains("not found") {
                Ok(HttpResponse::NotFound().json(&json!({
                    "error": format!("Order with ID {} not found", order_id)
                })))
            } else {
                Ok(HttpResponse::InternalServerError().json(&json!({
                    "error": format!("Failed to update order: {}", e)
                })))
            }
        }
    }
}

pub async fn cancel_energy_order(
    state: State<Arc<DatabaseService>>,
    order_id: web::types::Path<String>,
) -> Result<HttpResponse, ntex::web::Error> {
    let order_id_str = order_id.into_inner();
    let order_id = match Uuid::parse_str(&order_id_str) {
        Ok(id) => id,
        Err(_) => return Ok(HttpResponse::BadRequest().json(&json!({
            "error": "Invalid order ID format"
        })))
    };
    
    match state.cancel_order(order_id).await {
        Ok(order) => Ok(HttpResponse::Ok().json(&json!({
            "message": "Order cancelled successfully",
            "order": order
        }))),
        Err(e) => {
            if e.to_string().contains("not found") {
                Ok(HttpResponse::NotFound().json(&json!({
                    "error": format!("Order with ID {} not found", order_id)
                })))
            } else {
                Ok(HttpResponse::InternalServerError().json(&json!({
                    "error": format!("Failed to cancel order: {}", e)
                })))
            }
        }
    }
}

// Trade handlers
pub async fn execute_trade(
    state: State<Arc<DatabaseService>>,
    body: web::types::Json<ExecuteTradeRequest>,
) -> Result<HttpResponse, ntex::web::Error> {
    let trade = Trade {
        id: Uuid::new_v4(),
        buy_order_id: body.buy_order_id,
        sell_order_id: body.sell_order_id,
        buyer_address: "".to_string(), // Will be populated by the database
        seller_address: "".to_string(), // Will be populated by the database
        energy_amount: 0.0, // Will be calculated by the database
        price_per_unit: body.price_per_unit.unwrap_or(0.0),
        total_price: 0.0, // Will be calculated by the database
        status: "pending".to_string(),
        executed_at: Utc::now(),
        created_at: Utc::now(),
    };
    
    match state.execute_trade(trade).await {
        Ok(trade) => Ok(HttpResponse::Created().json(&trade)),
        Err(e) => Ok(HttpResponse::BadRequest().json(&json!({
            "error": format!("Failed to execute trade: {}", e)
        })))
    }
}

pub async fn get_trade(
    state: State<Arc<DatabaseService>>,
    trade_id: web::types::Path<String>,
) -> Result<HttpResponse, ntex::web::Error> {
    let trade_id_str = trade_id.into_inner();
    let trade_id = match Uuid::parse_str(&trade_id_str) {
        Ok(id) => id,
        Err(_) => return Ok(HttpResponse::BadRequest().json(&json!({
            "error": "Invalid trade ID format"
        })))
    };
    
    match state.get_trade(trade_id).await {
        Ok(trade) => Ok(HttpResponse::Ok().json(&trade)),
        Err(e) => {
            if e.to_string().contains("not found") {
                Ok(HttpResponse::NotFound().json(&json!({
                    "error": format!("Trade with ID {} not found", trade_id)
                })))
            } else {
                Ok(HttpResponse::InternalServerError().json(&json!({
                    "error": format!("Failed to get trade: {}", e)
                })))
            }
        }
    }
}

pub async fn get_all_trades(
    state: State<Arc<DatabaseService>>,
) -> Result<HttpResponse, ntex::web::Error> {
    match state.get_trades(0, 100).await {
        Ok(trades) => Ok(HttpResponse::Ok().json(&trades)),
        Err(e) => Ok(HttpResponse::InternalServerError().json(&json!({
            "error": format!("Failed to get trades: {}", e)
        })))
    }
}

// Token transfer handlers
pub async fn transfer_tokens(
    state: State<Arc<DatabaseService>>,
    body: web::types::Json<TransferTokensRequest>,
) -> Result<HttpResponse, ntex::web::Error> {
    match state.transfer_tokens(&body.from_address, &body.to_address, body.amount, &body.token_type).await {
        Ok(transfer_id) => Ok(HttpResponse::Ok().json(&json!({
            "message": "Tokens transferred successfully",
            "transfer_id": transfer_id
        }))),
        Err(e) => Ok(HttpResponse::BadRequest().json(&json!({
            "error": format!("Failed to transfer tokens: {}", e)
        })))
    }
}

// Statistics handlers
pub async fn get_market_stats(
    state: State<Arc<DatabaseService>>,
) -> Result<HttpResponse, ntex::web::Error> {
    match state.get_market_stats().await {
        Ok(stats) => Ok(HttpResponse::Ok().json(&stats)),
        Err(e) => Ok(HttpResponse::InternalServerError().json(&json!({
            "error": format!("Failed to get market stats: {}", e)
        })))
    }
}

pub async fn get_prosumer_stats(
    state: State<Arc<DatabaseService>>,
    address: web::types::Path<String>,
) -> Result<HttpResponse, ntex::web::Error> {
    let address = address.into_inner();
    match state.get_prosumer_stats(&address).await {
        Ok(stats) => Ok(HttpResponse::Ok().json(&stats)),
        Err(e) => {
            if e.to_string().contains("not found") {
                Ok(HttpResponse::NotFound().json(&json!({
                    "error": format!("Prosumer with address {} not found", address)
                })))
            } else {
                Ok(HttpResponse::InternalServerError().json(&json!({
                    "error": format!("Failed to get prosumer stats: {}", e)
                })))
            }
        }
    }
}

pub async fn get_database_stats(
    state: State<Arc<DatabaseService>>,
) -> Result<HttpResponse, ntex::web::Error> {
    match state.get_stats().await {
        Ok(stats) => Ok(HttpResponse::Ok().json(&stats)),
        Err(e) => Ok(HttpResponse::InternalServerError().json(&json!({
            "error": format!("Failed to get database stats: {}", e)
        })))
    }
}

// Order matching
pub async fn match_orders(
    state: State<Arc<DatabaseService>>,
) -> Result<HttpResponse, ntex::web::Error> {
    match state.match_orders().await {
        Ok(trades) => Ok(HttpResponse::Ok().json(&json!({
            "message": "Order matching completed",
            "trades": trades
        }))),
        Err(e) => Ok(HttpResponse::InternalServerError().json(&json!({
            "error": format!("Failed to match orders: {}", e)
        })))
    }
}