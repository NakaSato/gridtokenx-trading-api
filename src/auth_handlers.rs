use ntex::web::HttpResponse;
use serde_json::json;

// Placeholder auth handlers for now
pub async fn login() -> Result<HttpResponse, ntex::web::Error> {
    Ok(HttpResponse::Ok().json(&json!({
        "message": "Login endpoint - implementation pending"
    })))
}

pub async fn register() -> Result<HttpResponse, ntex::web::Error> {
    Ok(HttpResponse::Ok().json(&json!({
        "message": "Register endpoint - implementation pending"
    })))
}
