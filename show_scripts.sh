#!/bin/bash

#
# Project Scripts Overview
#
# This script provides an overview of all available scripts in the
# Energy Trading API project and their usage instructions.
#
# Usage: ./show_scripts.sh [script-name]
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Print header
print_header() {
    echo -e "${BOLD}${BLUE}🛠️  Energy Trading API - Available Scripts${NC}"
    echo "================================================="
    echo ""
}

# Print script info
print_script_info() {
    local script="$1"
    local description="$2"
    local usage="$3"
    local example="${4:-}"
    
    echo -e "${BOLD}${CYAN}📜 $script${NC}"
    echo -e "${YELLOW}Description:${NC} $description"
    echo -e "${YELLOW}Usage:${NC} $usage"
    if [[ -n "$example" ]]; then
        echo -e "${YELLOW}Example:${NC} $example"
    fi
    echo ""
}

# Show script details
show_script_details() {
    local script_name="$1"
    
    case "$script_name" in
        "setup_postgres.sh")
            print_script_info \
                "setup_postgres.sh" \
                "Sets up PostgreSQL database and creates .env configuration" \
                "./setup_postgres.sh [options]" \
                "./setup_postgres.sh --db-name mydb --user myuser"
            echo -e "${GREEN}Options:${NC}"
            echo "  -h, --help      Show help message"
            echo "  -d, --db-name   Database name (default: energy_trading)"
            echo "  -u, --user      Database user (default: postgres)"
            echo "  -p, --password  Database password (default: password)"
            echo "  --host          Database host (default: localhost)"
            echo "  --port          Database port (default: 5432)"
            ;;
            
        "test_api.sh")
            print_script_info \
                "test_api.sh" \
                "Basic API functionality testing with curl" \
                "./test_api.sh" \
                "./test_api.sh"
            echo -e "${GREEN}Requirements:${NC} curl, running API server"
            ;;
            
        "test_postgres.sh")
            print_script_info \
                "test_postgres.sh" \
                "PostgreSQL integration testing with database operations" \
                "./test_postgres.sh" \
                "./test_postgres.sh"
            echo -e "${GREEN}Requirements:${NC} PostgreSQL running, curl, configured .env"
            ;;
            
        "test_cancel_fix.sh")
            print_script_info \
                "test_cancel_fix.sh" \
                "Specialized test for order cancellation functionality" \
                "./test_cancel_fix.sh" \
                "./test_cancel_fix.sh"
            echo -e "${GREEN}Features:${NC} Comprehensive cancel order testing with server startup"
            ;;
            
        "run_tests.sh")
            print_script_info \
                "run_tests.sh" \
                "Comprehensive test suite runner with multiple test types" \
                "./run_tests.sh [options]" \
                "./run_tests.sh --coverage --verbose"
            echo -e "${GREEN}Options:${NC}"
            echo "  -h, --help          Show help message"
            echo "  -u, --unit          Run unit tests only"
            echo "  -i, --integration   Run integration tests only"
            echo "  -a, --api           Run API tests only"
            echo "  -p, --performance   Run performance tests"
            echo "  -v, --verbose       Enable verbose output"
            echo "  --coverage          Generate code coverage report"
            echo "  --no-cleanup        Don't cleanup test artifacts"
            ;;
            
        "validate_project.sh")
            print_script_info \
                "validate_project.sh" \
                "Complete project validation including code, config, and setup" \
                "./validate_project.sh [options]" \
                "./validate_project.sh --quick"
            echo -e "${GREEN}Options:${NC}"
            echo "  -h, --help      Show help message"
            echo "  -q, --quick     Run quick validation (no server tests)"
            echo "  -v, --verbose   Enable verbose output"
            echo "  --no-build      Skip build validation"
            echo "  --no-db         Skip database validation"
            echo "  --no-api        Skip API validation"
            ;;
            
        "deploy.sh")
            print_script_info \
                "deploy.sh" \
                "Kubernetes deployment automation with Docker image building" \
                "./deploy.sh [command] [options]" \
                "REGISTRY=myregistry.com/ ./deploy.sh deploy"
            echo -e "${GREEN}Commands:${NC}"
            echo "  build    - Build and push Docker image only"
            echo "  deploy   - Build, push, and deploy to Kubernetes (default)"
            echo "  status   - Check deployment status"
            echo "  cleanup  - Remove deployment from Kubernetes"
            echo "  help     - Show help message"
            echo ""
            echo -e "${GREEN}Environment Variables:${NC}"
            echo "  REGISTRY      - Container registry URL"
            echo "  IMAGE_TAG     - Docker image tag (default: latest)"
            echo "  NAMESPACE     - Kubernetes namespace (default: energy-trading)"
            ;;
            
        "clean_project.sh")
            print_script_info \
                "clean_project.sh" \
                "Format bash scripts, markdown files, and validate code style" \
                "./clean_project.sh" \
                "./clean_project.sh"
            echo -e "${GREEN}Features:${NC}"
            echo "  • Formats bash scripts with proper indentation"
            echo "  • Cleans markdown files and code blocks"
            echo "  • Validates script syntax"
            echo "  • Makes scripts executable"
            echo "  • Removes backup files"
            ;;
            
        *)
            echo -e "${RED}Unknown script: $script_name${NC}"
            echo "Available scripts: setup_postgres.sh, test_api.sh, test_postgres.sh,"
            echo "                  test_cancel_fix.sh, run_tests.sh, validate_project.sh,"
            echo "                  deploy.sh, clean_project.sh"
            return 1
            ;;
    esac
    echo ""
}

# Show all scripts overview
show_all_scripts() {
    print_script_info \
        "🐘 setup_postgres.sh" \
        "PostgreSQL setup and configuration" \
        "./setup_postgres.sh [options]" \
        "./setup_postgres.sh --db-name mydb"
    
    print_script_info \
        "🧪 test_api.sh" \
        "Basic API functionality testing" \
        "./test_api.sh" \
        ""
    
    print_script_info \
        "🐘 test_postgres.sh" \
        "PostgreSQL integration testing" \
        "./test_postgres.sh" \
        ""
    
    print_script_info \
        "❌ test_cancel_fix.sh" \
        "Order cancellation functionality test" \
        "./test_cancel_fix.sh" \
        ""
    
    print_script_info \
        "🏃 run_tests.sh" \
        "Comprehensive test suite runner" \
        "./run_tests.sh [options]" \
        "./run_tests.sh --coverage"
    
    print_script_info \
        "🔍 validate_project.sh" \
        "Complete project validation" \
        "./validate_project.sh [options]" \
        "./validate_project.sh --quick"
    
    print_script_info \
        "🚀 deploy.sh" \
        "Kubernetes deployment automation" \
        "./deploy.sh [command]" \
        "./deploy.sh deploy"
    
    print_script_info \
        "🧹 clean_project.sh" \
        "Code formatting and cleanup" \
        "./clean_project.sh" \
        ""
    
    echo -e "${BOLD}${GREEN}📚 Usage Tips:${NC}"
    echo "• Use --help flag with any script for detailed information"
    echo "• Run ./validate_project.sh first to check project setup"
    echo "• Use ./setup_postgres.sh to configure database"
    echo "• Run ./run_tests.sh for comprehensive testing"
    echo "• Use ./clean_project.sh before committing code"
    echo ""
    
    echo -e "${BOLD}${YELLOW}🔧 Development Workflow:${NC}"
    echo "1. ./setup_postgres.sh          # Setup database"
    echo "2. ./validate_project.sh --quick # Validate setup"
    echo "3. cargo run                     # Start development server"
    echo "4. ./run_tests.sh               # Run tests"
    echo "5. ./clean_project.sh           # Format code"
    echo "6. ./deploy.sh deploy           # Deploy to Kubernetes"
    echo ""
}

# Show script status
show_script_status() {
    echo -e "${BOLD}${BLUE}📊 Script Status${NC}"
    echo "=================="
    
    local scripts=(
        "setup_postgres.sh"
        "test_api.sh"
        "test_postgres.sh"
        "test_cancel_fix.sh"
        "run_tests.sh"
        "validate_project.sh"
        "deploy.sh"
        "clean_project.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                echo -e "${GREEN}✅ $script${NC} (executable)"
            else
                echo -e "${YELLOW}⚠️  $script${NC} (not executable)"
            fi
        else
            echo -e "${RED}❌ $script${NC} (missing)"
        fi
    done
    echo ""
}

# Main function
main() {
    print_header
    
    if [[ $# -eq 0 ]]; then
        show_script_status
        show_all_scripts
    elif [[ $# -eq 1 ]]; then
        case "$1" in
            "--status"|"-s")
                show_script_status
                ;;
            "--help"|"-h")
                echo "Usage: $0 [script-name|--status|--help]"
                echo ""
                echo "Show information about available scripts."
                echo ""
                echo "Options:"
                echo "  script-name  Show detailed info for specific script"
                echo "  --status     Show script availability status"
                echo "  --help       Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                    # Show all scripts"
                echo "  $0 run_tests.sh      # Show details for run_tests.sh"
                echo "  $0 --status          # Show script status"
                ;;
            *)
                if [[ "$1" == *.sh ]]; then
                    show_script_details "$1"
                else
                    show_script_details "$1.sh"
                fi
                ;;
        esac
    else
        echo "Usage: $0 [script-name|--status|--help]"
        exit 1
    fi
}

# Run main function
main "$@"
