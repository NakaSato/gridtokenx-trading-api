# PostgreSQL Setup Guide

## 🐘 PostgreSQL Configuration for Energy Trading API

This guide will help you set up PostgreSQL as the primary database for the Energy Trading API.

## Prerequisites

- PostgreSQL 12+ installed
- Rust 1.70+ with cargo
- Git

## Setup Options

### Option 1: Docker Compose (Recommended)

The easiest way to get started with PostgreSQL:

```bash
# Start PostgreSQL and pgAdmin
docker-compose up -d postgres

# Check if PostgreSQL is running
docker-compose ps
```bash

This will start:
- PostgreSQL on port 5432
- pgAdmin (optional) on port 8080

### Option 2: Automated Script

Use the provided setup script:

```bash
# Make the script executable
chmod +x setup_postgres.sh

# Run the setup
./setup_postgres.sh
```bash

### Option 3: Manual Setup

1. **Install PostgreSQL**
   ```bash
   # macOS
   brew install postgresql
   brew services start postgresql

   # Ubuntu/Debian
   sudo apt-get install postgresql postgresql-contrib
   sudo systemctl start postgresql

   # CentOS/RHEL
   sudo yum install postgresql-server postgresql-contrib
   sudo systemctl start postgresql
   ```

2. **Create Database and User**
   ```bash
   # Switch to postgres user (Linux)
   sudo -u postgres psql

   # Or connect directly (macOS)
   psql postgres

   # Create database
   CREATE DATABASE energy_trading;

   # Create user (optional)
   CREATE USER energy_trader WITH PASSWORD 'password';
   GRANT ALL PRIVILEGES ON DATABASE energy_trading TO energy_trader;

   # Exit
   \q
   ```

3. **Configure Environment**
   ```bash
   # Copy environment template
   cp .env.example .env

   # Edit .env file
   DATABASE_URL=postgresql://postgres:password@localhost:5432/energy_trading
   ```

## Environment Variables

Create a `.env` file with the following configuration:

```env
# Database Configuration
DATABASE_URL=postgresql://postgres:password@localhost:5432/energy_trading

# Server Configuration
PORT=3000
RUST_LOG=info

# JWT Secret (change in production!)
JWT_SECRET=your-super-secret-jwt-key-change-in-production

# Optional: Database Pool Configuration
DATABASE_MAX_CONNECTIONS=10
DATABASE_MIN_CONNECTIONS=1
```bash

## Database Schema

The API uses SQLx migrations to manage the database schema. The PostgreSQL schema includes:

- **users**: User accounts and authentication
- **api_keys**: API key management
- **prosumers**: Energy producers/consumers
- **orders**: Energy buy/sell orders
- **trades**: Executed trades

## Running the Application

1. **Start the Server**
   ```bash
   cargo run --bin api-server
   ```

2. **Migrations**
   Migrations run automatically on server startup. You can also run them manually:
   ```bash
   cargo install sqlx-cli
   sqlx migrate run --database-url postgresql://postgres:password@localhost:5432/energy_trading
   ```

## Testing the Database

```bash
# Test connection
psql -h localhost -p 5432 -U postgres -d energy_trading -c "SELECT 1;"

# View tables
psql -h localhost -p 5432 -U postgres -d energy_trading -c "\dt"

# Check API
curl http://localhost:3000/health
```bash

## Production Considerations

1. **Security**
   - Use strong passwords
   - Enable SSL/TLS
   - Configure firewall rules
   - Use connection pooling

2. **Performance**
   - Configure appropriate `shared_buffers`
   - Set up proper indexes
   - Monitor query performance
   - Use read replicas for scaling

3. **Backup**
   - Set up automated backups
   - Test backup restoration
   - Monitor disk space

## Troubleshooting

### Connection Issues

```bash
# Check if PostgreSQL is running
pg_isready -h localhost -p 5432

# Check logs
tail -f /var/log/postgresql/postgresql-*.log

# Test connection manually
psql -h localhost -p 5432 -U postgres
```bash

### Migration Issues

```bash
# Check migration status
sqlx migrate info --database-url $DATABASE_URL

# Reset migrations (development only)
sqlx database drop --database-url $DATABASE_URL
sqlx database create --database-url $DATABASE_URL
sqlx migrate run --database-url $DATABASE_URL
```bash

### Performance Issues

```bash
# Check active connections
SELECT count(*) FROM pg_stat_activity;

# Check slow queries
SELECT query, mean_time, calls
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```bash

## pgAdmin Access

If using Docker Compose, pgAdmin is available at:
- URL: http://localhost:8080
- Email: admin@energytrading.com
- Password: admin

Add server connection:
- Host: postgres (or localhost if not using Docker)
- Port: 5432
- Database: energy_trading
- Username: postgres
- Password: password
