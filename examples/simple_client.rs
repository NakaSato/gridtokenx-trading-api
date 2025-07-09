// Simple API client example
use reqwest::Client;
use serde_json::json;

const API_BASE: &str = "http://localhost:3000";

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::new();
    
    println!("🚀 Testing Energy Trading API");
    println!("=============================");
    
    // Test health endpoint
    println!("1. Testing health endpoint...");
    let response = client.get(&format!("{}/health", API_BASE)).send().await?;
    println!("   Status: {}", response.status());
    println!("   Response: {}", response.text().await?);
    
    // Create a prosumer
    println!("\n2. Creating a prosumer...");
    let response = client
        .post(&format!("{}/api/energy/prosumers", API_BASE))
        .json(&json!({
            "address": "alice_solar",
            "name": "Alice Solar Farm"
        }))
        .send()
        .await?;
    println!("   Status: {}", response.status());
    println!("   Response: {}", response.text().await?);
    
    // Create token account
    println!("\n3. Creating token account...");
    let response = client
        .post(&format!("{}/api/tokens/accounts", API_BASE))
        .json(&json!({
            "address": "alice_solar"
        }))
        .send()
        .await?;
    println!("   Status: {}", response.status());
    println!("   Response: {}", response.text().await?);
    
    // Update energy generation
    println!("\n4. Updating energy generation...");
    let response = client
        .post(&format!("{}/api/energy/generation", API_BASE))
        .json(&json!({
            "address": "alice_solar",
            "amount": 100.0
        }))
        .send()
        .await?;
    println!("   Status: {}", response.status());
    println!("   Response: {}", response.text().await?);
    
    // Create a sell order
    println!("\n5. Creating sell order...");
    let response = client
        .post(&format!("{}/api/energy/orders", API_BASE))
        .json(&json!({
            "trader_address": "alice_solar",
            "order_type": "sell",
            "energy_amount": 50.0,
            "price_per_kwh": 0.15
        }))
        .send()
        .await?;
    println!("   Status: {}", response.status());
    println!("   Response: {}", response.text().await?);
    
    // Get market statistics
    println!("\n6. Getting market statistics...");
    let response = client
        .get(&format!("{}/api/energy/statistics", API_BASE))
        .send()
        .await?;
    println!("   Status: {}", response.status());
    println!("   Response: {}", response.text().await?);
    
    // Get blockchain info
    println!("\n7. Getting blockchain info...");
    let response = client
        .get(&format!("{}/api/blockchain/info", API_BASE))
        .send()
        .await?;
    println!("   Status: {}", response.status());
    println!("   Response: {}", response.text().await?);
    
    println!("\n✅ API test completed!");
    
    Ok(())
}
