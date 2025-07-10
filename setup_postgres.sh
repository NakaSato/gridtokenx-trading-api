#!/bin/bash

#
# PostgreSQL Setup Script for Energy Trading API
#
# This script sets up PostgreSQL database and configuration for the
# Energy Trading API project, including database creation and .env setup.
#
# Usage: ./setup_postgres.sh [options]
# Options:
#   -h, --help     Show this help message
#   -d, --db-name  Database name (default: energy_trading)
#   -u, --user     Database user (default: postgres)
#   -p, --password Database password (default: password)
#   --host         Database host (default: localhost)
#   --port         Database port (default: 5432)
#

set -euo pipefail

# Default configuration
DB_NAME="energy_trading"
DB_USER="postgres"
DB_PASSWORD="password"
DB_HOST="localhost"
DB_PORT="5432"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print header
print_header() {
    echo -e "${BLUE}🐘 Setting up PostgreSQL for Energy Trading API${NC}"
    echo "=============================================="
    echo ""
}

# Show help message
show_help() {
    cat << EOF
Usage: $0 [options]

This script sets up PostgreSQL database and configuration for the
Energy Trading API project.

Options:
  -h, --help            Show this help message
  -d, --db-name NAME    Database name (default: energy_trading)
  -u, --user USER       Database user (default: postgres)
  -p, --password PASS   Database password (default: password)
  --host HOST           Database host (default: localhost)
  --port PORT           Database port (default: 5432)

Examples:
  $0                                    # Use default settings
  $0 -d mydb -u myuser -p mypass       # Custom database settings
  $0 --host 192.168.1.100 --port 5433 # Remote database

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--db-name)
                DB_NAME="$2"
                shift 2
                ;;
            -u|--user)
                DB_USER="$2"
                shift 2
                ;;
            -p|--password)
                DB_PASSWORD="$2"
                shift 2
                ;;
            --host)
                DB_HOST="$2"
                shift 2
                ;;
            --port)
                DB_PORT="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use '$0 --help' for usage information."
                exit 1
                ;;
        esac
    done
}

# Check if PostgreSQL is installed
check_postgresql_installation() {
    log_info "Checking PostgreSQL installation..."

    if ! command -v psql &> /dev/null; then
        log_error "PostgreSQL is not installed!"
        echo ""
        echo "Please install PostgreSQL first:"
        echo "  macOS:        brew install postgresql"
        echo "  Ubuntu/Debian: sudo apt-get install postgresql postgresql-contrib"
        echo "  CentOS/RHEL:   sudo yum install postgresql-server postgresql-contrib"
        echo "  Fedora:        sudo dnf install postgresql-server postgresql-contrib"
        echo ""
        exit 1
    fi

    log_success "PostgreSQL is installed"
}

# Check if PostgreSQL server is running
check_postgresql_service() {
    log_info "Checking PostgreSQL service status..."

    if ! pg_isready -h "$DB_HOST" -p "$DB_PORT" > /dev/null 2>&1; then
        log_error "PostgreSQL server is not running on $DB_HOST:$DB_PORT"
        echo ""
        echo "Please start PostgreSQL server:"
        echo "  macOS:   brew services start postgresql"
        echo "  Linux:   sudo systemctl start postgresql"
        echo ""
        echo "To enable automatic startup:"
        echo "  macOS:   brew services enable postgresql"
        echo "  Linux:   sudo systemctl enable postgresql"
        echo ""
        exit 1
    fi

    log_success "PostgreSQL server is running on $DB_HOST:$DB_PORT"
}

# Display configuration
show_configuration() {
    log_info "Using database configuration:"
    echo "  Database: $DB_NAME"
    echo "  User:     $DB_USER"
    echo "  Host:     $DB_HOST"
    echo "  Port:     $DB_PORT"
    echo "  Password: $(echo "$DB_PASSWORD" | sed 's/./*/g')"
    echo ""
}

# Create database
create_database() {
    log_info "Creating database '$DB_NAME'..."

    # Check if database already exists
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        log_warning "Database '$DB_NAME' already exists"
    else
        if createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" 2>/dev/null; then
            log_success "Database '$DB_NAME' created successfully"
        else
            log_error "Failed to create database '$DB_NAME'"
            log_error "Please check your PostgreSQL permissions and credentials"
            exit 1
        fi
    fi
}

# Test database connection
test_database_connection() {
    log_info "Testing database connection..."

    local database_url="postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"

    if psql "$database_url" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Database connection successful"
    else
        log_error "Database connection failed"
        log_error "Please verify your PostgreSQL configuration and credentials"
        exit 1
    fi
}

# Create .env file
create_env_file() {
    log_info "Creating .env file..."

    if [[ -f .env ]]; then
        log_warning ".env file already exists"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing .env file"
            return 0
        fi

        # Backup existing .env file
        cp .env ".env.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Existing .env file backed up"
    fi

    cat > .env << EOF
# Energy Trading API Environment Configuration
# Generated on $(date)

# Database Configuration
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME

# Server Configuration
PORT=3000
RUST_LOG=info

# JWT Secret (CHANGE IN PRODUCTION!)
JWT_SECRET=your-super-secret-jwt-key-change-in-production-$(openssl rand -hex 16)

# Database Pool Configuration
DATABASE_MAX_CONNECTIONS=10
DATABASE_MIN_CONNECTIONS=1

# API Configuration
API_VERSION=1.0.0
API_TIMEOUT_SECONDS=30

# Security Configuration (for production)
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
RATE_LIMIT_REQUESTS_PER_MINUTE=100

# Optional: Logging Configuration
LOG_LEVEL=info
LOG_FORMAT=json
EOF

    log_success ".env file created successfully"
}

# Show completion message and next steps
show_completion() {
    echo ""
    echo "=================================="
    log_success "PostgreSQL setup completed! 🎉"
    echo "=================================="
    echo ""
    echo "🚀 Next steps:"
    echo "1. Review the .env file and update settings as needed"
    echo "2. Run 'cargo run --bin api-server' to start the server"
    echo "3. The server will automatically run migrations on startup"
    echo "4. Access the API at http://localhost:3000"
    echo "5. Test the setup with './test_postgres.sh'"
    echo ""
    echo "📋 Configuration summary:"
    echo "  Database URL: postgresql://$DB_USER:***@$DB_HOST:$DB_PORT/$DB_NAME"
    echo "  API Server:   http://localhost:3000"
    echo "  Log Level:    info"
    echo ""
    echo "⚠️  Security note:"
    echo "  - Change the JWT_SECRET in .env for production use"
    echo "  - Update CORS_ALLOWED_ORIGINS for your domain"
    echo "  - Consider using environment-specific configuration"
    echo ""
}

# Main function
main() {
    print_header
    parse_arguments "$@"
    check_postgresql_installation
    check_postgresql_service
    show_configuration
    create_database
    test_database_connection
    create_env_file
    show_completion
}

# Run main function with all arguments
main "$@"
echo ""
echo "Database URL: postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
