// Import the server module directly 
use std::io;

#[ntex::main]
async fn main() -> io::Result<()> {
    println!("🌟 Energy Trading API Server 🌟");
    println!("================================");
    
    // Start the API server on port 3000
    energy_trading_api::server::start_server(3000).await
}
