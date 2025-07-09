use crate::handlers::*;
use crate::middleware::{cors_layer, request_logging, auth_middleware, security_headers_middleware};
use crate::auth::AuthStore;
use crate::auth_handlers::*;
use axum::{
    middleware,
    routing::{get, post, delete},
    Router,
};
use std::sync::{Arc, Mutex};

pub fn create_app() -> Router {
    let state = Arc::new(Mutex::new(LedgerState::new()));
    let auth_store = Arc::new(AuthStore::new());

    // Public routes (no authentication required) 
    let public_routes = Router::new()
        .route("/health", get(health_check))
        .route("/api/auth/login", post(login))
        .route("/api/auth/register", post(register))
        .with_state(auth_store.clone());

    // Authentication management routes (require authentication)
    let auth_routes = Router::new()
        .route("/api/auth/me", get(get_current_user))
        .route("/api/auth/refresh", post(refresh_token))
        .route("/api/auth/api-keys", get(list_api_keys))
        .route("/api/auth/api-keys", post(create_api_key))
        .route("/api/auth/api-keys/:key_id", delete(revoke_api_key))
        .with_state(auth_store.clone())
        .layer(middleware::from_fn_with_state(auth_store.clone(), auth_middleware));

    // Business logic routes (require authentication)
    let business_routes = Router::new()
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
        .layer(middleware::from_fn_with_state(auth_store.clone(), auth_middleware));

    // Combine all routes
    Router::new()
        .merge(public_routes)
        .merge(auth_routes)
        .merge(business_routes)
        .layer(middleware::from_fn(security_headers_middleware))
        .layer(middleware::from_fn(request_logging))
        .layer(cors_layer())
}

pub async fn start_server(port: u16) {
    let app = create_app();
    
    println!("🚀 Energy Trading Ledger API Server starting on port {}", port);
    println!("🔐 Authentication enabled with JWT and API Key support");
    println!("📋 Available endpoints:");
    
    // Public endpoints
    println!("   🌐 Public endpoints:");
    println!("   GET  /health - Health check");
    println!("   POST /api/auth/login - User login");
    println!("   POST /api/auth/register - User registration");
    
    // Protected endpoints
    println!("   🔒 Protected endpoints (require authentication):");
    println!("   GET  /api/auth/me - Get current user info");
    println!("   POST /api/auth/refresh - Refresh JWT token");
    println!("   GET  /api/auth/api-keys - List user's API keys");
    println!("   POST /api/auth/api-keys - Create new API key");
    println!("   DEL  /api/auth/api-keys/:key_id - Revoke API key");
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
    
    println!("\n🔑 Authentication methods:");
    println!("   Bearer Token: Authorization: Bearer <jwt_token>");
    println!("   API Key: X-API-Key: <api_key>");
    println!("\n👤 Default admin user:");
    println!("   Username: admin");
    println!("   Password: admin123");
    
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{}", port))
        .await
        .unwrap();
    
    axum::serve(listener, app).await.unwrap();
}
