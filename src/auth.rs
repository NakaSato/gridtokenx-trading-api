use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use jsonwebtoken::{decode, encode, Algorithm, DecodingKey, EncodingKey, Header, Validation};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use uuid::Uuid;
use base64::Engine;

// JWT Claims structure
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    pub sub: String,         // Subject (user ID)
    pub name: String,        // User name
    pub role: String,        // User role (admin, trader, readonly)
    pub exp: usize,          // Expiration time
    pub iat: usize,          // Issued at
    pub jti: String,         // JWT ID
}

// API Key structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiKey {
    pub id: String,
    pub name: String,
    pub key_hash: String,
    pub user_id: String,
    pub role: String,
    pub permissions: Vec<String>,
    pub created_at: DateTime<Utc>,
    pub last_used: Option<DateTime<Utc>>,
    pub expires_at: Option<DateTime<Utc>>,
    pub is_active: bool,
}

// User structure for authentication
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub username: String,
    pub email: String,
    pub password_hash: String,
    pub role: String,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub last_login: Option<DateTime<Utc>>,
}

// Authentication request structures
#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct CreateApiKeyRequest {
    pub name: String,
    pub permissions: Vec<String>,
    pub expires_in_days: Option<u32>,
}

#[derive(Debug, Deserialize)]
pub struct CreateUserRequest {
    pub username: String,
    pub email: String,
    pub password: String,
    pub role: String,
}

// Authentication response structures
#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub access_token: String,
    pub token_type: String,
    pub expires_in: usize,
    pub user: UserInfo,
}

#[derive(Debug, Serialize)]
pub struct UserInfo {
    pub id: String,
    pub username: String,
    pub email: String,
    pub role: String,
}

#[derive(Debug, Serialize)]
pub struct ApiKeyResponse {
    pub id: String,
    pub name: String,
    pub key: String,
    pub permissions: Vec<String>,
    pub expires_at: Option<DateTime<Utc>>,
}

// Authentication errors
#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("Invalid credentials")]
    InvalidCredentials,
    #[error("Token expired")]
    TokenExpired,
    #[error("Invalid token")]
    InvalidToken,
    #[error("Insufficient permissions")]
    InsufficientPermissions,
    #[error("User not found")]
    UserNotFound,
    #[error("API key not found")]
    ApiKeyNotFound,
    #[error("User already exists")]
    UserAlreadyExists,
    #[error("Internal error: {0}")]
    Internal(String),
}

// In-memory storage for demonstration (in production, use a database)
pub struct AuthStore {
    pub users: Arc<Mutex<HashMap<String, User>>>,
    pub api_keys: Arc<Mutex<HashMap<String, ApiKey>>>,
    pub jwt_secret: String,
}

impl AuthStore {
    pub fn new() -> Self {
        let store = Self {
            users: Arc::new(Mutex::new(HashMap::new())),
            api_keys: Arc::new(Mutex::new(HashMap::new())),
            jwt_secret: std::env::var("JWT_SECRET").unwrap_or_else(|_| {
                "your-super-secret-jwt-key-change-in-production".to_string()
            }),
        };

        // Create default admin user
        store.create_default_admin();
        store
    }

    fn create_default_admin(&self) {
        let admin_user = User {
            id: Uuid::new_v4().to_string(),
            username: "admin".to_string(),
            email: "admin@energy-trading.com".to_string(),
            password_hash: bcrypt::hash("admin123", bcrypt::DEFAULT_COST).unwrap(),
            role: "admin".to_string(),
            is_active: true,
            created_at: Utc::now(),
            last_login: None,
        };

        let mut users = self.users.lock().unwrap();
        users.insert(admin_user.id.clone(), admin_user);
    }

    pub fn authenticate_user(&self, username: &str, password: &str) -> Result<User, AuthError> {
        let users = self.users.lock().unwrap();
        
        let user = users.values()
            .find(|u| u.username == username && u.is_active)
            .ok_or(AuthError::InvalidCredentials)?;

        if bcrypt::verify(password, &user.password_hash)
            .map_err(|_| AuthError::Internal("Password verification failed".to_string()))? {
            Ok(user.clone())
        } else {
            Err(AuthError::InvalidCredentials)
        }
    }

    pub fn create_user(&self, request: CreateUserRequest) -> Result<User, AuthError> {
        let mut users = self.users.lock().unwrap();
        
        // Check if user already exists
        if users.values().any(|u| u.username == request.username || u.email == request.email) {
            return Err(AuthError::UserAlreadyExists);
        }

        let user = User {
            id: Uuid::new_v4().to_string(),
            username: request.username,
            email: request.email,
            password_hash: bcrypt::hash(&request.password, bcrypt::DEFAULT_COST)
                .map_err(|_| AuthError::Internal("Password hashing failed".to_string()))?,
            role: request.role,
            is_active: true,
            created_at: Utc::now(),
            last_login: None,
        };

        users.insert(user.id.clone(), user.clone());
        Ok(user)
    }

    pub fn generate_jwt(&self, user: &User) -> Result<String, AuthError> {
        let exp = (Utc::now() + chrono::Duration::hours(24)).timestamp() as usize;
        let iat = Utc::now().timestamp() as usize;
        
        let claims = Claims {
            sub: user.id.clone(),
            name: user.username.clone(),
            role: user.role.clone(),
            exp,
            iat,
            jti: Uuid::new_v4().to_string(),
        };

        encode(
            &Header::default(),
            &claims,
            &EncodingKey::from_secret(self.jwt_secret.as_bytes()),
        )
        .map_err(|_| AuthError::Internal("JWT encoding failed".to_string()))
    }

    pub fn validate_jwt(&self, token: &str) -> Result<Claims, AuthError> {
        decode::<Claims>(
            token,
            &DecodingKey::from_secret(self.jwt_secret.as_bytes()),
            &Validation::default(),
        )
        .map(|data| data.claims)
        .map_err(|_| AuthError::InvalidToken)
    }

    pub fn create_api_key(&self, user_id: &str, request: CreateApiKeyRequest) -> Result<ApiKeyResponse, AuthError> {
        let key = format!("etapi_{}", base64::engine::general_purpose::STANDARD.encode(rand::random::<[u8; 32]>()));
        let key_hash = bcrypt::hash(&key, bcrypt::DEFAULT_COST)
            .map_err(|_| AuthError::Internal("Key hashing failed".to_string()))?;

        let expires_at = request.expires_in_days.map(|days| {
            Utc::now() + chrono::Duration::days(days as i64)
        });

        let api_key = ApiKey {
            id: Uuid::new_v4().to_string(),
            name: request.name.clone(),
            key_hash,
            user_id: user_id.to_string(),
            role: "api".to_string(),
            permissions: request.permissions.clone(),
            created_at: Utc::now(),
            last_used: None,
            expires_at,
            is_active: true,
        };

        let mut api_keys = self.api_keys.lock().unwrap();
        api_keys.insert(api_key.id.clone(), api_key.clone());

        Ok(ApiKeyResponse {
            id: api_key.id,
            name: api_key.name,
            key,
            permissions: api_key.permissions,
            expires_at: api_key.expires_at,
        })
    }

    pub fn validate_api_key(&self, key: &str) -> Result<ApiKey, AuthError> {
        let mut api_keys = self.api_keys.lock().unwrap();
        
        for api_key in api_keys.values_mut() {
            if api_key.is_active && 
               api_key.expires_at.map_or(true, |exp| exp > Utc::now()) &&
               bcrypt::verify(key, &api_key.key_hash).unwrap_or(false) {
                
                // Update last used timestamp
                api_key.last_used = Some(Utc::now());
                return Ok(api_key.clone());
            }
        }
        
        Err(AuthError::ApiKeyNotFound)
    }

    pub fn get_user_by_id(&self, user_id: &str) -> Result<User, AuthError> {
        let users = self.users.lock().unwrap();
        users.get(user_id)
            .cloned()
            .ok_or(AuthError::UserNotFound)
    }

    pub fn verify_jwt(token: &str, secret: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
        let key = DecodingKey::from_secret(secret.as_ref());
        let validation = Validation::new(Algorithm::HS256);
        
        match decode::<Claims>(token, &key, &validation) {
            Ok(token_data) => Ok(token_data.claims),
            Err(err) => Err(err),
        }
    }
}

// Permission checking
pub fn check_permission(user_role: &str, required_permission: &str) -> bool {
    match user_role {
        "admin" => true, // Admin has all permissions
        "trader" => matches!(required_permission, "read" | "trade" | "create_order" | "cancel_order"),
        "readonly" => matches!(required_permission, "read"),
        _ => false,
    }
}

// Endpoint permissions mapping
pub fn get_endpoint_permission(method: &str, path: &str) -> &'static str {
    match (method, path) {
        ("GET", _) => "read",
        ("POST", path) if path.contains("/orders") => "trade",
        ("POST", path) if path.contains("/cancel") => "cancel_order",
        ("POST", _) => "create",
        ("PUT", _) => "update",
        ("DELETE", _) => "delete",
        _ => "read",
    }
}
