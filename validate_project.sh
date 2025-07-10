#!/bin/bash

#
# Project Validation Script for Energy Trading API
#
# This script validates the entire project setup including:
# - Code compilation
# - Database connectivity
# - API functionality
# - Configuration files
# - Documentation completeness
#
# Usage: ./validate_project.sh [options]
# Options:
#   -h, --help      Show this help message
#   -q, --quick     Run quick validation only (no server tests)
#   -v, --verbose   Enable verbose output
#   --no-build      Skip build validation
#   --no-db         Skip database validation
#   --no-api        Skip API validation
#

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$SCRIPT_DIR"
readonly API_BASE_URL="http://localhost:3000"
readonly TIMEOUT=30

# Options
QUICK_MODE=false
VERBOSE=false
SKIP_BUILD=false
SKIP_DB=false
SKIP_API=false

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((TESTS_PASSED++))
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((TESTS_FAILED++))
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Print header
print_header() {
    echo -e "${BOLD}${BLUE}🔍 Energy Trading API Project Validation${NC}"
    echo "=============================================="
    echo "Project: $(basename "$PROJECT_ROOT")"
    echo "Mode: $([ "$QUICK_MODE" == "true" ] && echo "Quick" || echo "Full")"
    echo "Verbose: $VERBOSE"
    echo ""
}

# Show help message
show_help() {
    cat << EOF
Usage: $0 [options]

This script validates the entire Energy Trading API project setup.

Options:
  -h, --help      Show this help message
  -q, --quick     Run quick validation only (no server tests)
  -v, --verbose   Enable verbose output
  --no-build      Skip build validation
  --no-db         Skip database validation
  --no-api        Skip API validation

Examples:
  $0                    # Full validation
  $0 --quick           # Quick validation (no server startup)
  $0 --verbose         # Full validation with verbose output
  $0 --no-api          # Skip API tests (useful for CI)

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
            -q|--quick)
                QUICK_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --no-build)
                SKIP_BUILD=true
                shift
                ;;
            --no-db)
                SKIP_DB=true
                shift
                ;;
            --no-api)
                SKIP_API=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use '$0 --help' for usage information."
                exit 1
                ;;
        esac
    done
}

# Check if required tools are installed
check_system_requirements() {
    log_info "Checking system requirements..."
    
    local required_tools=("rustc" "cargo")
    local optional_tools=("docker" "psql" "curl" "jq")
    
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "$tool is installed"
            log_verbose "$tool version: $(command "$tool" --version 2>/dev/null | head -n1 || echo "unknown")"
        else
            log_error "$tool is required but not installed"
            return 1
        fi
    done
    
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "$tool is available"
            log_verbose "$tool version: $(command "$tool" --version 2>/dev/null | head -n1 || echo "unknown")"
        else
            log_warning "$tool is not installed (optional but recommended)"
        fi
    done
}

# Validate project structure
validate_project_structure() {
    log_info "Validating project structure..."
    
    local required_files=(
        "Cargo.toml"
        "src/main.rs"
        "src/lib.rs"
        "src/handlers.rs"
        "src/models.rs"
        "src/server.rs"
        "README.md"
    )
    
    local required_dirs=(
        "src"
        "migrations"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "File exists: $file"
        else
            log_error "Missing required file: $file"
        fi
    done
    
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_success "Directory exists: $dir"
        else
            log_error "Missing required directory: $dir"
        fi
    done
    
    # Check for shell scripts
    local scripts=(*.sh)
    if [[ ${#scripts[@]} -gt 0 && -f "${scripts[0]}" ]]; then
        log_success "Found ${#scripts[@]} shell script(s)"
        for script in "${scripts[@]}"; do
            if [[ -x "$script" ]]; then
                log_verbose "Script is executable: $script"
            else
                log_warning "Script not executable: $script"
            fi
        done
    else
        log_warning "No shell scripts found"
    fi
}

# Validate Cargo.toml and dependencies
validate_cargo_config() {
    log_info "Validating Cargo configuration..."
    
    if [[ -f "Cargo.toml" ]]; then
        log_success "Cargo.toml exists"
        
        # Check for required dependencies
        local required_deps=("ntex" "sqlx" "tokio" "serde")
        for dep in "${required_deps[@]}"; do
            if grep -q "^$dep = " Cargo.toml; then
                log_success "Dependency found: $dep"
            else
                log_warning "Missing dependency: $dep"
            fi
        done
        
        # Check for PostgreSQL feature
        if grep -q "features.*postgres" Cargo.toml; then
            log_success "PostgreSQL feature enabled in sqlx"
        else
            log_warning "PostgreSQL feature not found in sqlx configuration"
        fi
        
    else
        log_error "Cargo.toml not found"
    fi
}

# Validate code compilation
validate_build() {
    if [[ "$SKIP_BUILD" == "true" ]]; then
        log_info "Skipping build validation (--no-build)"
        return 0
    fi
    
    log_info "Validating code compilation..."
    
    log_verbose "Running cargo check..."
    if cargo check --all-targets --all-features &> /dev/null; then
        log_success "Code passes cargo check"
    else
        log_error "Code fails cargo check"
        return 1
    fi
    
    log_verbose "Running cargo clippy..."
    if cargo clippy --all-targets --all-features -- -D warnings &> /dev/null; then
        log_success "Code passes clippy lints"
    else
        log_warning "Code has clippy warnings/errors"
    fi
    
    if [[ "$QUICK_MODE" == "false" ]]; then
        log_verbose "Running full build..."
        if cargo build --release --all-features &> /dev/null; then
            log_success "Release build successful"
        else
            log_error "Release build failed"
            return 1
        fi
    fi
}

# Validate environment configuration
validate_environment() {
    log_info "Validating environment configuration..."
    
    if [[ -f ".env" ]]; then
        log_success ".env file exists"
        
        # Check for required environment variables
        local required_vars=("DATABASE_URL")
        for var in "${required_vars[@]}"; do
            if grep -q "^$var=" .env; then
                log_success "Environment variable defined: $var"
            else
                log_warning "Missing environment variable: $var"
            fi
        done
    else
        log_warning ".env file not found"
    fi
    
    if [[ -f ".env.example" ]]; then
        log_success ".env.example file exists"
    else
        log_warning ".env.example file not found"
    fi
}

# Validate database connectivity
validate_database() {
    if [[ "$SKIP_DB" == "true" ]]; then
        log_info "Skipping database validation (--no-db)"
        return 0
    fi
    
    log_info "Validating database connectivity..."
    
    # Load environment variables
    if [[ -f ".env" ]]; then
        source .env
    fi
    
    if [[ -n "${DATABASE_URL:-}" ]]; then
        log_success "DATABASE_URL is set"
        
        # Test database connection with psql if available
        if command -v psql &> /dev/null; then
            log_verbose "Testing database connection with psql..."
            if psql "$DATABASE_URL" -c "SELECT 1;" &> /dev/null; then
                log_success "Database connection successful"
            else
                log_warning "Database connection failed"
            fi
        else
            log_warning "psql not available, skipping direct database test"
        fi
    else
        log_warning "DATABASE_URL not set"
    fi
    
    # Check migration files
    if [[ -d "migrations" ]]; then
        local migration_count
        migration_count=$(find migrations -name "*.sql" | wc -l)
        if [[ $migration_count -gt 0 ]]; then
            log_success "Found $migration_count migration file(s)"
        else
            log_warning "No migration files found"
        fi
    fi
}

# Validate API functionality (if not in quick mode)
validate_api() {
    if [[ "$SKIP_API" == "true" ]]; then
        log_info "Skipping API validation (--no-api)"
        return 0
    fi
    
    if [[ "$QUICK_MODE" == "true" ]]; then
        log_info "Skipping API validation (quick mode)"
        return 0
    fi
    
    log_info "Validating API functionality..."
    
    if ! command -v curl &> /dev/null; then
        log_warning "curl not available, skipping API tests"
        return 0
    fi
    
    # Start server in background for testing
    log_verbose "Starting server for API testing..."
    local server_log="validation_server.log"
    cargo run > "$server_log" 2>&1 &
    local server_pid=$!
    
    # Cleanup function
    cleanup_server() {
        if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
            log_verbose "Stopping test server..."
            kill "$server_pid" 2>/dev/null || true
            wait "$server_pid" 2>/dev/null || true
        fi
        [[ -f "$server_log" ]] && rm -f "$server_log"
    }
    
    trap cleanup_server EXIT
    
    # Wait for server to start
    log_verbose "Waiting for server to start..."
    local retries=10
    local count=0
    
    while [[ $count -lt $retries ]]; do
        if curl -s --max-time 5 "$API_BASE_URL/health" > /dev/null 2>&1; then
            log_success "Server started and responding"
            break
        fi
        
        if ! kill -0 "$server_pid" 2>/dev/null; then
            log_error "Server process died unexpectedly"
            cat "$server_log"
            return 1
        fi
        
        ((count++))
        sleep 2
    done
    
    if [[ $count -eq $retries ]]; then
        log_error "Server failed to start within timeout"
        cat "$server_log"
        return 1
    fi
    
    # Test health endpoint
    log_verbose "Testing health endpoint..."
    if curl -s --max-time 5 "$API_BASE_URL/health" | grep -q "ok"; then
        log_success "Health endpoint working"
    else
        log_error "Health endpoint failed"
    fi
    
    # Test basic API endpoints (simplified)
    local endpoints=("/api/energy/prosumers" "/api/energy/orders/buy" "/api/energy/orders/sell")
    for endpoint in "${endpoints[@]}"; do
        log_verbose "Testing endpoint: $endpoint"
        if curl -s --max-time 5 "$API_BASE_URL$endpoint" > /dev/null; then
            log_success "Endpoint responding: $endpoint"
        else
            log_warning "Endpoint not responding: $endpoint"
        fi
    done
    
    cleanup_server
    trap - EXIT
}

# Validate documentation
validate_documentation() {
    log_info "Validating documentation..."
    
    local doc_files=("README.md" "POSTGRESQL_SETUP.md" "REVERSE_PROXY_GUIDE.md")
    
    for doc in "${doc_files[@]}"; do
        if [[ -f "$doc" ]]; then
            log_success "Documentation exists: $doc"
            
            # Basic content checks
            if [[ -s "$doc" ]]; then
                log_verbose "Document has content: $doc"
            else
                log_warning "Document is empty: $doc"
            fi
        else
            log_warning "Missing documentation: $doc"
        fi
    done
    
    # Check for code examples in README
    if [[ -f "README.md" ]] && grep -q '```' README.md; then
        log_success "README contains code examples"
    else
        log_warning "README may lack code examples"
    fi
}

# Print validation summary
print_summary() {
    echo ""
    echo "=============================================="
    echo -e "${BOLD}🎯 Validation Summary${NC}"
    echo "=============================================="
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "Warnings: $WARNINGS"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        if [[ $WARNINGS -eq 0 ]]; then
            echo -e "${GREEN}${BOLD}🎉 Project validation PASSED with no issues!${NC}"
        else
            echo -e "${YELLOW}${BOLD}✅ Project validation PASSED with $WARNINGS warning(s)${NC}"
        fi
        echo ""
        echo "✨ Your Energy Trading API project is ready for deployment!"
        return 0
    else
        echo -e "${RED}${BOLD}❌ Project validation FAILED${NC}"
        echo ""
        echo "Please fix the issues above before deployment."
        return 1
    fi
}

# Main function
main() {
    print_header
    parse_arguments "$@"
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # Run validation steps
    check_system_requirements
    validate_project_structure
    validate_cargo_config
    validate_environment
    validate_database
    validate_build
    validate_api
    validate_documentation
    
    # Print summary and exit with appropriate code
    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
