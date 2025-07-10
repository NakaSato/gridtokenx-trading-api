#!/bin/bash

# PostgreSQL Setup Script for Energy Trading API

echo "🐘 Setting up PostgreSQL for Energy Trading API"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo -e "${RED}PostgreSQL is not installed. Please install PostgreSQL first.${NC}"
    echo "On macOS: brew install postgresql"
    echo "On Ubuntu: sudo apt-get install postgresql postgresql-contrib"
    echo "On CentOS/RHEL: sudo yum install postgresql-server postgresql-contrib"
    exit 1
fi

# Default database configuration
DB_NAME="energy_trading"
DB_USER="postgres"
DB_PASSWORD="password"
DB_HOST="localhost"
DB_PORT="5432"

echo -e "${YELLOW}Using default database configuration:${NC}"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Password: $DB_PASSWORD"
echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo ""

# Check if PostgreSQL is running
if ! pg_isready -h $DB_HOST -p $DB_PORT > /dev/null 2>&1; then
    echo -e "${RED}PostgreSQL server is not running on $DB_HOST:$DB_PORT${NC}"
    echo "Please start PostgreSQL server first:"
    echo "On macOS: brew services start postgresql"
    echo "On Linux: sudo systemctl start postgresql"
    exit 1
fi

echo -e "${GREEN}✓ PostgreSQL server is running${NC}"

# Create database if it doesn't exist
echo "Creating database '$DB_NAME'..."
createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database '$DB_NAME' created successfully${NC}"
else
    echo -e "${YELLOW}Database '$DB_NAME' already exists or couldn't create${NC}"
fi

# Create .env file
echo "Creating .env file..."
cat > .env << EOF
# Energy Trading API Environment Configuration

# Database Configuration
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME

# Server Configuration
PORT=3000
RUST_LOG=info

# JWT Secret (change in production!)
JWT_SECRET=your-super-secret-jwt-key-change-in-production

# Optional: Database Pool Configuration
DATABASE_MAX_CONNECTIONS=10
DATABASE_MIN_CONNECTIONS=1

# Optional: API Configuration
API_VERSION=1.0.0
API_TIMEOUT_SECONDS=30
EOF

echo -e "${GREEN}✓ .env file created${NC}"

# Test database connection
echo "Testing database connection..."
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Database connection successful${NC}"
else
    echo -e "${RED}✗ Database connection failed${NC}"
    echo "Please check your PostgreSQL configuration and credentials."
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 PostgreSQL setup completed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Run 'cargo run --bin api-server' to start the server"
echo "2. The server will automatically run migrations on startup"
echo "3. Access the API at http://localhost:3000"
echo ""
echo "Database URL: postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
