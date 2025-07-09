use energy_trading_api::server::start_server;

#[tokio::main]
async fn main() {
    println!("🌟 Energy Trading Ledger - API Server 🌟");
    println!("==========================================");
    
    // Start the API server on port 3000
    start_server(3000).await;
}
