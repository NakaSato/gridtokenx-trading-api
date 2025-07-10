use std::sync::Arc;
use std::io;

use ntex::web::{self, middleware, App, HttpServer};

use crate::database::DatabaseService;
use crate::handlers;

pub async fn start_server(port: u16) -> io::Result<()> {
    env_logger::init();

    // Load environment variables from .env file if it exists
    dotenv::dotenv().ok();

    // Get database URL from environment or use PostgreSQL default
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://postgres:password@localhost:5432/energy_trading".to_string());
    
    log::info!("Connecting to database: {}", database_url);
    
    // Initialize database service
    let db_service = match DatabaseService::new(&database_url).await {
        Ok(service) => {
            log::info!("Database connection established");
            service
        }
        Err(e) => {
            log::error!("Failed to connect to database: {}", e);
            std::process::exit(1);
        }
    };

    // Run migrations
    if let Err(e) = db_service.run_migrations().await {
        log::error!("Failed to run migrations: {}", e);
        std::process::exit(1);
    }
    log::info!("Database migrations completed");

    let db_service = Arc::new(db_service);

    log::info!("Starting Energy Trading API server on port {}", port);

    HttpServer::new(move || {
        App::new()
            .state(db_service.clone())
            .wrap(middleware::Logger::default())
            .wrap(middleware::DefaultHeaders::new().header("X-Version", "1.0.0"))
            .service(
                web::resource("/")
                    .route(web::get().to(handlers::root))
            )
            .service(
                web::resource("/health")
                    .route(web::get().to(handlers::health_check))
            )
            // Prosumer endpoints
            .service(
                web::resource("/prosumers")
                    .route(web::post().to(handlers::create_prosumer))
                    .route(web::get().to(handlers::get_all_prosumers))
            )
            .service(
                web::resource("/prosumers/{address}")
                    .route(web::get().to(handlers::get_prosumer))
                    .route(web::put().to(handlers::update_prosumer))
            )
            .service(
                web::resource("/prosumers/{address}/stats")
                    .route(web::get().to(handlers::get_prosumer_stats))
            )
            // Order endpoints
            .service(
                web::resource("/orders")
                    .route(web::post().to(handlers::create_energy_order))
                    .route(web::get().to(handlers::get_all_energy_orders))
            )
            .service(
                web::resource("/orders/{order_id}")
                    .route(web::get().to(handlers::get_energy_order))
                    .route(web::put().to(handlers::update_energy_order))
                    .route(web::delete().to(handlers::cancel_energy_order))
            )
            // Trade endpoints
            .service(
                web::resource("/trades")
                    .route(web::post().to(handlers::execute_trade))
                    .route(web::get().to(handlers::get_all_trades))
            )
            .service(
                web::resource("/trades/{trade_id}")
                    .route(web::get().to(handlers::get_trade))
            )
            // Token transfer endpoints
            .service(
                web::resource("/transfer")
                    .route(web::post().to(handlers::transfer_tokens))
            )
            // Statistics endpoints
            .service(
                web::resource("/stats/market")
                    .route(web::get().to(handlers::get_market_stats))
            )
            .service(
                web::resource("/stats/database")
                    .route(web::get().to(handlers::get_database_stats))
            )
            // Order matching
            .service(
                web::resource("/match-orders")
                    .route(web::post().to(handlers::match_orders))
            )
    })
    .bind(format!("127.0.0.1:{}", port))?
    .run()
    .await
}
