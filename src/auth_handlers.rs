use crate::auth::{AuthStore, LoginRequest, CreateUserRequest, CreateApiKeyRequest, LoginResponse, UserInfo, ApiKeyResponse, AuthError};
use crate::middleware::AuthContext;
use crate::models::ApiResponse;
use axum::{
    extract::{Extension, State},
    response::Json,
    http::StatusCode,
};
use std::sync::Arc;
use chrono::Utc;

// Login endpoint
pub async fn login(
    State(auth_store): State<Arc<AuthStore>>,
    Json(request): Json<LoginRequest>,
) -> Result<Json<ApiResponse<LoginResponse>>, (StatusCode, Json<ApiResponse<String>>)> {
    match auth_store.authenticate_user(&request.username, &request.password) {
        Ok(mut user) => {
            // Update last login timestamp
            {
                let mut users = auth_store.users.lock().unwrap();
                if let Some(stored_user) = users.get_mut(&user.id) {
                    stored_user.last_login = Some(Utc::now());
                    user.last_login = Some(Utc::now());
                }
            }
            
            match auth_store.generate_jwt(&user) {
                Ok(token) => {
                    let response = LoginResponse {
                        access_token: token,
                        token_type: "Bearer".to_string(),
                        expires_in: 24 * 3600, // 24 hours
                        user: UserInfo {
                            id: user.id,
                            username: user.username,
                            email: user.email,
                            role: user.role,
                        },
                    };
                    Ok(Json(ApiResponse::success(response)))
                }
                Err(e) => Err(handle_auth_error(e)),
            }
        }
        Err(e) => Err(handle_auth_error(e)),
    }
}

// Register new user endpoint
pub async fn register(
    State(auth_store): State<Arc<AuthStore>>,
    Json(request): Json<CreateUserRequest>,
) -> Result<Json<ApiResponse<UserInfo>>, (StatusCode, Json<ApiResponse<String>>)> {
    match auth_store.create_user(request) {
        Ok(user) => {
            let user_info = UserInfo {
                id: user.id,
                username: user.username,
                email: user.email,
                role: user.role,
            };
            Ok(Json(ApiResponse::success(user_info)))
        }
        Err(e) => Err(handle_auth_error(e)),
    }
}

// Create API key endpoint
pub async fn create_api_key(
    State(auth_store): State<Arc<AuthStore>>,
    Extension(auth_ctx): Extension<AuthContext>,
    Json(request): Json<CreateApiKeyRequest>,
) -> Result<Json<ApiResponse<ApiKeyResponse>>, (StatusCode, Json<ApiResponse<String>>)> {
    match auth_store.create_api_key(&auth_ctx.user_id, request) {
        Ok(api_key) => Ok(Json(ApiResponse::success(api_key))),
        Err(e) => Err(handle_auth_error(e)),
    }
}

// Get current user info endpoint
pub async fn get_current_user(
    State(auth_store): State<Arc<AuthStore>>,
    Extension(auth_ctx): Extension<AuthContext>,
) -> Result<Json<ApiResponse<UserInfo>>, (StatusCode, Json<ApiResponse<String>>)> {
    match auth_store.get_user_by_id(&auth_ctx.user_id) {
        Ok(user) => {
            let user_info = UserInfo {
                id: user.id,
                username: user.username,
                email: user.email,
                role: user.role,
            };
            Ok(Json(ApiResponse::success(user_info)))
        }
        Err(e) => Err(handle_auth_error(e)),
    }
}

// List user's API keys endpoint
pub async fn list_api_keys(
    State(auth_store): State<Arc<AuthStore>>,
    Extension(auth_ctx): Extension<AuthContext>,
) -> Json<ApiResponse<Vec<ApiKeyInfo>>> {
    let api_keys = auth_store.api_keys.lock().unwrap();
    let user_keys: Vec<ApiKeyInfo> = api_keys
        .values()
        .filter(|key| key.user_id == auth_ctx.user_id)
        .map(|key| ApiKeyInfo {
            id: key.id.clone(),
            name: key.name.clone(),
            permissions: key.permissions.clone(),
            created_at: key.created_at,
            last_used: key.last_used,
            expires_at: key.expires_at,
            is_active: key.is_active,
        })
        .collect();
    
    Json(ApiResponse::success(user_keys))
}

// Revoke API key endpoint
pub async fn revoke_api_key(
    State(auth_store): State<Arc<AuthStore>>,
    Extension(auth_ctx): Extension<AuthContext>,
    axum::extract::Path(key_id): axum::extract::Path<String>,
) -> Result<Json<ApiResponse<String>>, (StatusCode, Json<ApiResponse<String>>)> {
    let mut api_keys = auth_store.api_keys.lock().unwrap();
    
    if let Some(api_key) = api_keys.get_mut(&key_id) {
        if api_key.user_id == auth_ctx.user_id || auth_ctx.role == "admin" {
            api_key.is_active = false;
            Ok(Json(ApiResponse::success("API key revoked successfully".to_string())))
        } else {
            Err((
                StatusCode::FORBIDDEN,
                Json(ApiResponse::error("You don't have permission to revoke this API key".to_string())),
            ))
        }
    } else {
        Err((
            StatusCode::NOT_FOUND,
            Json(ApiResponse::error("API key not found".to_string())),
        ))
    }
}

// Refresh JWT token endpoint
pub async fn refresh_token(
    State(auth_store): State<Arc<AuthStore>>,
    Extension(auth_ctx): Extension<AuthContext>,
) -> Result<Json<ApiResponse<LoginResponse>>, (StatusCode, Json<ApiResponse<String>>)> {
    match auth_store.get_user_by_id(&auth_ctx.user_id) {
        Ok(user) => {
            match auth_store.generate_jwt(&user) {
                Ok(token) => {
                    let response = LoginResponse {
                        access_token: token,
                        token_type: "Bearer".to_string(),
                        expires_in: 24 * 3600, // 24 hours
                        user: UserInfo {
                            id: user.id,
                            username: user.username,
                            email: user.email,
                            role: user.role,
                        },
                    };
                    Ok(Json(ApiResponse::success(response)))
                }
                Err(e) => Err(handle_auth_error(e)),
            }
        }
        Err(e) => Err(handle_auth_error(e)),
    }
}

// Supporting structures
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Serialize)]
pub struct ApiKeyInfo {
    pub id: String,
    pub name: String,
    pub permissions: Vec<String>,
    pub created_at: DateTime<Utc>,
    pub last_used: Option<DateTime<Utc>>,
    pub expires_at: Option<DateTime<Utc>>,
    pub is_active: bool,
}

// Helper function to handle auth errors
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
