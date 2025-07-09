use crate::handlers::*;
use crate::middleware::{cors_layer, request_logging};
use axum::{
    middleware,
    routing::{get, post},
    Router,
};
use std::sync::{Arc, Mutex};

pub fn create_app() -> Router {
    let state = Arc::new(Mutex::new(LedgerState::new()));

    Router::new()
        // Health check
        .route("/health", get(health_check))
        
        // Blockchain endpoints
        .route("/api/blockchain/info", get(get_blockchain_info))
        .route("/api/blockchain/blocks", get(get_blocks))
        .route("/api/blockchain/blocks/:index", get(get_block))
        .route("/api/blockchain/mine", post(mine_block))
        .route("/api/blockchain/transactions/pending", get(get_pending_transactions))
        
        // Token system endpoints
        .route("/api/tokens/accounts", post(create_token_account))
        .route("/api/tokens/balance/:address", get(get_token_balance))
        .route("/api/tokens/transfer", post(transfer_tokens))
        .route("/api/tokens/stake", post(stake_tokens))
        .route("/api/tokens/unstake", post(unstake_tokens))
        .route("/api/tokens/rewards/:address", post(claim_rewards))
        
        // Governance endpoints
        .route("/api/governance/proposals", get(get_governance_proposals))
        .route("/api/governance/proposals", post(create_governance_proposal))
        .route("/api/governance/vote", post(vote_on_proposal))
        
        // Energy trading endpoints
        .route("/api/energy/prosumers", post(create_prosumer))
        .route("/api/energy/prosumers", get(get_all_prosumers))
        .route("/api/energy/prosumers/:address", get(get_prosumer))
        .route("/api/energy/generation", post(update_energy_generation))
        .route("/api/energy/consumption", post(update_energy_consumption))
        
        // Order management endpoints
        .route("/api/energy/orders", post(create_energy_order))
        .route("/api/energy/orders/cancel", post(cancel_energy_order))
        .route("/api/energy/orders/buy", get(get_buy_orders))
        .route("/api/energy/orders/sell", get(get_sell_orders))
        
        // Market data endpoints
        .route("/api/energy/trades", get(get_trade_history))
        .route("/api/energy/statistics", get(get_market_statistics))
        
        .with_state(state)
        .layer(middleware::from_fn(request_logging))
        .layer(cors_layer())
}

pub async fn start_server(port: u16) {
    let app = create_app();
    
    println!("🚀 Energy Trading Ledger API Server starting on port {}", port);
    println!("📋 Available endpoints:");
    println!("   GET  /health - Health check");
    println!("   GET  /api/blockchain/info - Get blockchain information");
    println!("   GET  /api/blockchain/blocks - Get all blocks");
    println!("   GET  /api/blockchain/blocks/:index - Get specific block");
    println!("   POST /api/blockchain/mine - Mine a new block");
    println!("   GET  /api/blockchain/transactions/pending - Get pending transactions");
    println!("   POST /api/tokens/accounts - Create token account");
    println!("   GET  /api/tokens/balance/:address - Get token balance");
    println!("   POST /api/tokens/transfer - Transfer tokens");
    println!("   POST /api/tokens/stake - Stake tokens");
    println!("   POST /api/tokens/unstake - Unstake tokens");
    println!("   POST /api/tokens/rewards/:address - Claim staking rewards");
    println!("   GET  /api/governance/proposals - Get governance proposals");
    println!("   POST /api/governance/proposals - Create governance proposal");
    println!("   POST /api/governance/vote - Vote on proposal");
    println!("   POST /api/energy/prosumers - Create prosumer");
    println!("   GET  /api/energy/prosumers - Get all prosumers");
    println!("   GET  /api/energy/prosumers/:address - Get specific prosumer");
    println!("   POST /api/energy/generation - Update energy generation");
    println!("   POST /api/energy/consumption - Update energy consumption");
    println!("   POST /api/energy/orders - Create energy order");
    println!("   POST /api/energy/orders/cancel - Cancel energy order");
    println!("   GET  /api/energy/orders/buy - Get buy orders");
    println!("   GET  /api/energy/orders/sell - Get sell orders");
    println!("   GET  /api/energy/trades - Get trade history");
    println!("   GET  /api/energy/statistics - Get market statistics");
    
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port))
        .await
        .unwrap();
    
    axum::serve(listener, app).await.unwrap();
}
