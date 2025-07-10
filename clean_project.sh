#!/bin/bash

#
# Clean and Format Project Scripts
#
# This script formats bash scripts and markdown files for consistency
# Usage: ./clean_project.sh
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    print_message "$BLUE" "🧹 $1"
}

print_success() {
    print_message "$GREEN" "✅ $1"
}

print_warning() {
    print_message "$YELLOW" "⚠️  $1"
}

print_error() {
    print_message "$RED" "❌ $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to clean bash scripts
clean_bash_scripts() {
    print_header "Cleaning Bash Scripts"
    
    local bash_files=(
        "setup_postgres.sh"
        "test_postgres.sh"
        "test_api.sh"
        "deploy.sh"
    )
    
    for file in "${bash_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_message "$BLUE" "  Formatting $file..."
            
            # Add proper shebang if missing
            if ! head -n1 "$file" | grep -q "^#!/bin/bash"; then
                sed -i.bak '1i#!/bin/bash\n' "$file"
            fi
            
            # Remove trailing whitespace
            sed -i.bak 's/[[:space:]]*$//' "$file"
            
            # Ensure file ends with newline
            if [[ -n "$(tail -c1 "$file")" ]]; then
                echo >> "$file"
            fi
            
            # Make executable
            chmod +x "$file"
            
            print_success "    ✓ $file formatted and made executable"
        else
            print_warning "    File $file not found, skipping"
        fi
    done
}

# Function to clean markdown files
clean_markdown_files() {
    print_header "Cleaning Markdown Files"
    
    local md_files=(
        "README.md"
        "POSTGRESQL_SETUP.md"
        "REVERSE_PROXY_GUIDE.md"
        "DEPLOYMENT.md"
    )
    
    for file in "${md_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_message "$BLUE" "  Formatting $file..."
            
            # Remove trailing whitespace
            sed -i.bak 's/[[:space:]]*$//' "$file"
            
            # Ensure file ends with newline
            if [[ -n "$(tail -c1 "$file")" ]]; then
                echo >> "$file"
            fi
            
            # Fix common markdown issues
            # Fix multiple empty lines
            sed -i.bak '/^$/N;/^\n$/d' "$file"
            
            print_success "    ✓ $file formatted"
        else
            print_warning "    File $file not found, skipping"
        fi
    done
}

# Function to validate bash scripts
validate_bash_scripts() {
    print_header "Validating Bash Scripts"
    
    local has_errors=false
    
    for script in *.sh; do
        if [[ -f "$script" ]]; then
            print_message "$BLUE" "  Checking $script..."
            
            # Check syntax
            if bash -n "$script" 2>/dev/null; then
                print_success "    ✓ $script syntax OK"
            else
                print_error "    ✗ $script has syntax errors"
                has_errors=true
            fi
            
            # Check if executable
            if [[ -x "$script" ]]; then
                print_success "    ✓ $script is executable"
            else
                print_warning "    ! $script is not executable"
                chmod +x "$script"
                print_success "    ✓ Made $script executable"
            fi
        fi
    done
    
    if [[ "$has_errors" == true ]]; then
        print_error "Some scripts have syntax errors. Please fix them."
        return 1
    fi
}

# Function to check markdown links
check_markdown_links() {
    print_header "Checking Markdown Links"
    
    if command_exists "markdown-link-check"; then
        for file in *.md; do
            if [[ -f "$file" ]]; then
                print_message "$BLUE" "  Checking links in $file..."
                if markdown-link-check "$file" --quiet; then
                    print_success "    ✓ All links in $file are valid"
                else
                    print_warning "    ! Some links in $file may be broken"
                fi
            fi
        done
    else
        print_warning "markdown-link-check not installed. Skipping link validation."
        print_message "$YELLOW" "  Install with: npm install -g markdown-link-check"
    fi
}

# Function to format code blocks in markdown
format_markdown_code_blocks() {
    print_header "Formatting Code Blocks in Markdown"
    
    for file in *.md; do
        if [[ -f "$file" ]]; then
            print_message "$BLUE" "  Formatting code blocks in $file..."
            
            # Ensure code blocks have proper language tags
            # This is a simple approach - could be more sophisticated
            sed -i.bak 's/^```$/```bash/' "$file"
            
            print_success "    ✓ Code blocks in $file formatted"
        fi
    done
}

# Function to clean backup files
clean_backup_files() {
    print_header "Cleaning Backup Files"
    
    local backup_files=(*.bak)
    
    if [[ -f "${backup_files[0]}" ]]; then
        for file in "${backup_files[@]}"; do
            rm -f "$file"
            print_success "  ✓ Removed $file"
        done
    else
        print_message "$BLUE" "  No backup files to clean"
    fi
}

# Function to run prettier if available
run_prettier() {
    print_header "Running Prettier (if available)"
    
    if command_exists "prettier"; then
        print_message "$BLUE" "  Running prettier on markdown files..."
        prettier --write "*.md" 2>/dev/null || true
        print_success "  ✓ Prettier formatting complete"
    else
        print_warning "  Prettier not found. Install with: npm install -g prettier"
    fi
}

# Main execution
main() {
    print_message "$GREEN" "🧹 Cleaning and Formatting Energy Trading API Project"
    print_message "$GREEN" "=================================================="
    echo
    
    # Run cleaning functions
    clean_bash_scripts
    echo
    
    clean_markdown_files
    echo
    
    validate_bash_scripts
    echo
    
    format_markdown_code_blocks
    echo
    
    check_markdown_links
    echo
    
    run_prettier
    echo
    
    clean_backup_files
    echo
    
    print_message "$GREEN" "🎉 Project cleaning complete!"
    print_message "$GREEN" "=================================================="
    echo
    
    print_message "$BLUE" "Summary:"
    print_message "$GREEN" "  ✅ Bash scripts formatted and validated"
    print_message "$GREEN" "  ✅ Markdown files cleaned"
    print_message "$GREEN" "  ✅ Code blocks formatted"
    print_message "$GREEN" "  ✅ Backup files removed"
    echo
    
    print_message "$YELLOW" "Optional improvements:"
    print_message "$YELLOW" "  📦 Install prettier: npm install -g prettier"
    print_message "$YELLOW" "  🔗 Install markdown-link-check: npm install -g markdown-link-check"
    print_message "$YELLOW" "  🎨 Install shellcheck: brew install shellcheck (macOS) or apt install shellcheck (Ubuntu)"
}

# Error handling
trap 'print_error "Script failed on line $LINENO"' ERR

# Run main function
main "$@"
