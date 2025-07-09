use axum::{
    extract::{Request, State},
    middleware::Next,
    response::Response,
    http::{StatusCode, HeaderMap},
    Json,
};
use tower_http::cors::{Any, CorsLayer};
use crate::auth::{AuthStore, Claims, AuthError, check_permission, get_endpoint_permission};
use crate::models::ApiResponse;
use std::sync::Arc;

// Authentication context that gets added to request extensions
#[derive(Debug, Clone)]
pub struct AuthContext {
    pub user_id: String,
    pub username: String,
    pub role: String,
    pub auth_type: AuthType,
}

#[derive(Debug, Clone)]
pub enum AuthType {
    JWT,
    ApiKey,
}

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
    
    // Log request with authentication context if available
    if let Some(auth_ctx) = request.extensions().get::<AuthContext>() {
        println!("📡 {} {} - Started (User: {}, Role: {})", method, uri, auth_ctx.username, auth_ctx.role);
    } else {
        println!("📡 {} {} - Started (Unauthenticated)", method, uri);
    }
    
    let response = next.run(request).await;
    
    let duration = start.elapsed();
    let status = response.status();
    
    if status.is_success() {
        println!("✅ {} {} - {} - Completed in {:?}", method, uri, status, duration);
    } else {
        println!("❌ {} {} - {} - Failed in {:?}", method, uri, status, duration);
    }
    
    response
}

// Main authentication middleware
pub async fn auth_middleware(
    State(auth_store): State<Arc<AuthStore>>,
    mut request: Request,
    next: Next,
) -> Result<Response, (StatusCode, Json<ApiResponse<String>>)> {
    let path = request.uri().path();
    let method = request.method().as_str();
    
    // Skip authentication for health check and auth endpoints
    if is_public_endpoint(path) {
        return Ok(next.run(request).await);
    }
    
    // Extract authentication from headers
    let headers = request.headers();
    let auth_context = match extract_auth_context(headers, &auth_store).await {
        Ok(ctx) => ctx,
        Err(auth_error) => {
            return Err(handle_auth_error(auth_error));
        }
    };
    
    // Check permissions
    let required_permission = get_endpoint_permission(method, path);
    if !check_permission(&auth_context.role, required_permission) {
        return Err((
            StatusCode::FORBIDDEN,
            Json(ApiResponse::error("Insufficient permissions".to_string())),
        ));
    }
    
    // Add auth context to request extensions for use in handlers
    request.extensions_mut().insert(auth_context);
    
    Ok(next.run(request).await)
}

// Extract authentication context from headers
async fn extract_auth_context(
    headers: &HeaderMap,
    auth_store: &AuthStore,
) -> Result<AuthContext, AuthError> {
    // Try JWT token first (Bearer token)
    if let Some(auth_header) = headers.get("Authorization") {
        if let Ok(auth_str) = auth_header.to_str() {
            if auth_str.starts_with("Bearer ") {
                let token = &auth_str[7..]; // Remove "Bearer " prefix
                let claims = auth_store.validate_jwt(token)?;
                let user = auth_store.get_user_by_id(&claims.sub)?;
                
                return Ok(AuthContext {
                    user_id: user.id,
                    username: user.username,
                    role: user.role,
                    auth_type: AuthType::JWT,
                });
            }
        }
    }
    
    // Try API Key authentication
    if let Some(api_key_header) = headers.get("X-API-Key") {
        if let Ok(api_key) = api_key_header.to_str() {
            let api_key_info = auth_store.validate_api_key(api_key)?;
            let user = auth_store.get_user_by_id(&api_key_info.user_id)?;
            
            return Ok(AuthContext {
                user_id: user.id,
                username: user.username,
                role: api_key_info.role,
                auth_type: AuthType::ApiKey,
            });
        }
    }
    
    Err(AuthError::InvalidToken)
}

// Check if endpoint is public (doesn't require authentication)
fn is_public_endpoint(path: &str) -> bool {
    matches!(path, 
        "/health" | 
        "/api/auth/login" | 
        "/api/auth/register" |
        "/api/auth/refresh" |
        "/metrics" |
        "/docs" |
        "/swagger-ui" |
        "/openapi.json"
    )
}

// Handle authentication errors
fn handle_auth_error(error: AuthError) -> (StatusCode, Json<ApiResponse<String>>) {
    match error {
        AuthError::InvalidCredentials => (
            StatusCode::UNAUTHORIZED,
            Json(ApiResponse::error("Invalid credentials".to_string())),
        ),
        AuthError::TokenExpired => (
            StatusCode::UNAUTHORIZED,
            Json(ApiResponse::error("Token expired".to_string())),
        ),
        AuthError::InvalidToken => (
            StatusCode::UNAUTHORIZED,
            Json(ApiResponse::error("Invalid or missing authentication token".to_string())),
        ),
        AuthError::InsufficientPermissions => (
            StatusCode::FORBIDDEN,
            Json(ApiResponse::error("Insufficient permissions".to_string())),
        ),
        AuthError::UserNotFound => (
            StatusCode::UNAUTHORIZED,
            Json(ApiResponse::error("User not found".to_string())),
        ),
        AuthError::ApiKeyNotFound => (
            StatusCode::UNAUTHORIZED,
            Json(ApiResponse::error("Invalid API key".to_string())),
        ),
        AuthError::UserAlreadyExists => (
            StatusCode::CONFLICT,
            Json(ApiResponse::error("User already exists".to_string())),
        ),
        AuthError::Internal(msg) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ApiResponse::error(format!("Internal error: {}", msg))),
        ),
    }
}

// Rate limiting middleware (basic implementation)
pub async fn rate_limit_middleware(request: Request, next: Next) -> Response {
    // In production, implement proper rate limiting with Redis or similar
    // For now, this is a placeholder that allows all requests
    next.run(request).await
}

// Security headers middleware
pub async fn security_headers_middleware(request: Request, next: Next) -> Response {
    let mut response = next.run(request).await;
    
    let headers = response.headers_mut();
    headers.insert("X-Content-Type-Options", "nosniff".parse().unwrap());
    headers.insert("X-Frame-Options", "DENY".parse().unwrap());
    headers.insert("X-XSS-Protection", "1; mode=block".parse().unwrap());
    headers.insert("Strict-Transport-Security", "max-age=31536000; includeSubDomains".parse().unwrap());
    headers.insert("Content-Security-Policy", "default-src 'self'".parse().unwrap());
    
    response
}
