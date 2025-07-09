use axum::{
    extract::Request,
    middleware::Next,
    response::Response,
};
use tower_http::cors::{Any, CorsLayer};

// CORS middleware configuration
pub fn cors_layer() -> CorsLayer {
    CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any)
}

// Request logging middleware
pub async fn request_logging(request: Request, next: Next) -> Response {
    let method = request.method().clone();
    let uri = request.uri().clone();
    let start = std::time::Instant::now();
    
    println!("📡 {} {} - Started", method, uri);
    
    let response = next.run(request).await;
    
    let duration = start.elapsed();
    println!("📡 {} {} - Completed in {:?}", method, uri, duration);
    
    response
}

// Authentication middleware (for future use)
pub async fn auth_middleware(request: Request, next: Next) -> Response {
    // For demonstration purposes, we'll skip authentication
    // In production, validate API keys or JWT tokens here
    next.run(request).await
}
