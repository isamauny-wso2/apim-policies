#!/bin/bash

# WSO2 APIM Policy Installation Script
# This script automatically installs all AI guardrail policies via the Publisher REST API

set -e  # Exit on any error

# Show help and exit if --help is provided
show_help() {
    echo "WSO2 APIM Policy Installation Script"
    echo "====================================="
    echo ""
    echo "This script automatically installs all AI guardrail policies via the Publisher REST API"
    echo ""
    echo "Usage: ./install-policies.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help    Show this help message and exit"
    echo ""
    echo "Password Authentication Options:"
    echo "  1. Interactive prompt (most secure - default):"
    echo "     ./install-policies.sh"
    echo ""
    echo "  2. Password file (secure):"
    echo "     echo 'your-password' > ~/.wso2-admin-pass"
    echo "     chmod 600 ~/.wso2-admin-pass"
    echo "     export ADMIN_PASS_FILE=~/.wso2-admin-pass"
    echo "     ./install-policies.sh"
    echo ""
    echo "  3. Environment variable (less secure):"
    echo "     export ADMIN_PASS=your-password"
    echo "     ./install-policies.sh"
    echo ""
    echo "Configuration Options (via environment variables):"
    echo "  APIM_HOST     - WSO2 APIM hostname (default: localhost)"
    echo "  APIM_PORT     - WSO2 APIM port (default: 9443)"
    echo "  ADMIN_USER    - Admin username (default: admin)"
    echo "  ADMIN_PASS    - Admin password (not recommended for security)"
    echo "  ADMIN_PASS_FILE - Path to file containing admin password"
    echo ""
    exit 0
}

# Check for --help argument
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
BUILD_OUTPUT_DIR="$PROJECT_ROOT/build-output"
INSTALL_LOG="$BUILD_OUTPUT_DIR/install.log"

# Configuration (can be overridden by environment variables)
APIM_HOST="${APIM_HOST:-localhost}"
APIM_PORT="${APIM_PORT:-9443}"
ADMIN_USER="${ADMIN_USER:-admin}"

# Set curl options based on hostname
if [ "$APIM_HOST" = "localhost" ] || [ "$APIM_HOST" = "127.0.0.1" ]; then
    CURL_INSECURE="-k"
else
    CURL_INSECURE=""
fi

# Secure password handling - multiple methods supported
get_secure_password() {
    local password=""
    
    # Method 1: Check if password is already set via environment
    if [ -n "$ADMIN_PASS" ]; then
        password="$ADMIN_PASS"
        log_info "Using password from environment variable" >&2
    
    # Method 2: Check for password file
    elif [ -n "$ADMIN_PASS_FILE" ] && [ -f "$ADMIN_PASS_FILE" ]; then
        password=$(cat "$ADMIN_PASS_FILE" | tr -d '\n\r')
        log_info "Using password from file: $ADMIN_PASS_FILE" >&2
        
        # Validate password was read
        if [ -z "$password" ]; then
            log_error "Password file is empty: $ADMIN_PASS_FILE" >&2
            return 1
        fi
    
    # Method 3: Prompt user for password (hidden input)
    else
        echo -n "Enter WSO2 Admin Password: " >&2
        read -s password
        echo "" >&2  # New line after hidden input
        
        if [ -z "$password" ]; then
            log_error "Password cannot be empty" >&2
            return 1
        fi
        log_info "Using password from interactive prompt" >&2
    fi
    
    echo "$password"
}

# Shared log function - displays colors on screen, writes clean text to log
log() {
    local color="$1"
    local message="$2"
    local log_prefix="$3"
    
    # Display colored message to screen (force flush)
    echo -e "${color}${message}${NC}"
    
    # Write clean message to log file
    echo "${log_prefix}${message}" >> "$INSTALL_LOG"
}

# Convenience functions for different log levels
log_info() {
    log "" "$1" "[INFO] "
}

log_success() {
    log "$GREEN" "$1" "[SUCCESS] "
}

log_warning() {
    log "$YELLOW" "$1" "[WARNING] "
}

log_error() {
    log "$RED" "$1" "[ERROR] "
}

log_header() {
    log "$BLUE" "$1" "[HEADER] "
}

# Create build output directory and initialize log
mkdir -p "$BUILD_OUTPUT_DIR"
echo "WSO2 APIM Policy Installation Script" > "$INSTALL_LOG"
echo "====================================" >> "$INSTALL_LOG"
echo "Installation started at: $(date)" >> "$INSTALL_LOG"
echo "" >> "$INSTALL_LOG"

log_header "WSO2 APIM Policy Installation Script"
echo "=========================================="
log_info "APIM Host: $APIM_HOST:$APIM_PORT"
log_info "Admin User: $ADMIN_USER"
log_info "Project root: $PROJECT_ROOT" 
log_info "Install log: $INSTALL_LOG"
if [ "$APIM_HOST" = "localhost" ] || [ "$APIM_HOST" = "127.0.0.1" ]; then
    log_info "Using insecure curl connection for localhost"
fi
echo ""

# Get secure password
log_header "Authentication Setup"
ADMIN_PASS=$(get_secure_password)
if [ $? -ne 0 ] || [ -z "$ADMIN_PASS" ]; then
    log_error "Failed to obtain admin password. Exiting."
    exit 1
fi
echo ""

# Check prerequisites
log_header "Checking prerequisites..."

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed. Please install jq to continue."
    log_info "Install with: brew install jq (macOS) or apt-get install jq (Ubuntu)"
    exit 1
fi
log_success "✓ jq is available"

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    log_error "curl is required but not installed. Please install curl to continue."
    exit 1
fi
log_success "✓ curl is available"

echo ""

# Function to get OAuth2 access token
get_access_token() {
    {
    log_info "Obtaining OAuth2 access token..."
    
    # First, test server connectivity
    log_info "Testing server connectivity..."
    if ! curl $CURL_INSECURE -s --connect-timeout 10 "https://$APIM_HOST:$APIM_PORT/services/Version" > /dev/null; then
        log_warning "Could not connect to WSO2 server. Checking if server is reachable..."
    fi
    
    # Register OAuth2 client application
    log_info "Registering OAuth2 client application..."
    log_info "Using endpoint: https://$APIM_HOST:$APIM_PORT/client-registration/v0.17/register"
    
    # Create secure authorization header without exposing password
    # Use printf to avoid any echo interpretation issues
    local auth_header=$(printf "%s:%s" "$ADMIN_USER" "$ADMIN_PASS" | base64)
    log_info "Authorization header created (length: ${#auth_header})"
    
    # Try the client registration endpoint (may need to be insecure for self-signed certs)
    CLIENT_RESPONSE=$(curl $CURL_INSECURE -s -X POST "https://$APIM_HOST:$APIM_PORT/client-registration/v0.17/register" \
        -H "Authorization: Basic $auth_header" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d '{
            "callbackUrl": "www.google.lk",
            "clientName": "policy_deployment_client",
            "owner": "'"$ADMIN_USER"'",
            "grantType": "client_credentials password refresh_token",
            "saasApp": true
        }')
    
    # Clear auth_header variable immediately
    unset auth_header
    
    local curl_exit_code=$?
    if [ $curl_exit_code -ne 0 ] || [ -z "$CLIENT_RESPONSE" ]; then
        log_error "Failed to register OAuth2 client application"
        log_error "Curl exit code: $curl_exit_code"
        log_info "Response: $CLIENT_RESPONSE"
        log_info "URL attempted: https://$APIM_HOST:$APIM_PORT/client-registration/v0.17/register"
        return 1
    fi
    
    CLIENT_ID=$(echo "$CLIENT_RESPONSE" | jq -r '.clientId // empty')
    CLIENT_SECRET=$(echo "$CLIENT_RESPONSE" | jq -r '.clientSecret // empty')
    
    if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_ID" = "null" ] || [ "$CLIENT_SECRET" = "null" ]; then
        log_error "Failed to extract client credentials from registration response"
        log_info "Response: $CLIENT_RESPONSE"
        return 1
    fi
    
    log_success "✓ OAuth2 client registered successfully"
    log_info "Client ID: $CLIENT_ID"
    
    # Obtain access token using password grant
    log_info "Obtaining access token..."
    
    # Create secure client authorization header
    local client_auth_header=$(printf "%s:%s" "$CLIENT_ID" "$CLIENT_SECRET" | base64)
    
    TOKEN_RESPONSE=$(curl $CURL_INSECURE -s -X POST "https://$APIM_HOST:$APIM_PORT/oauth2/token" \
        -H "Authorization: Basic $client_auth_header" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password&username=$ADMIN_USER&password=$ADMIN_PASS&scope=apim:common_operation_policy_manage apim:api_create apim:api_publish apim:api_view" \
        2>/dev/null)
    
    # Clear sensitive variables immediately
    unset client_auth_header
    
    local token_curl_exit_code=$?
    if [ $token_curl_exit_code -ne 0 ] || [ -z "$TOKEN_RESPONSE" ]; then
        log_error "Failed to obtain access token"
        log_error "Curl exit code: $token_curl_exit_code"
        log_info "Response: $TOKEN_RESPONSE"
        log_info "URL attempted: https://$APIM_HOST:$APIM_PORT/oauth2/token"
        return 1
    fi
    
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')
    
    if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
        log_error "Failed to extract access token from response"
        log_info "Response: $TOKEN_RESPONSE"
        return 1
    fi
    
    log_success "✓ Access token obtained successfully"
    
    } >&2
    echo "$ACCESS_TOKEN"
}

# Function to deploy a single policy
deploy_policy() {
    local policy_name="$1"
    local resources_dir="$2"
    local access_token="$3"
    
    local policy_def_file="$resources_dir/policy-definition.json"
    local artifact_file="$resources_dir/artifact.j2"
    
    # Check if required files exist
    if [ ! -f "$policy_def_file" ]; then
        log_error "Policy definition file not found: $policy_def_file"
        return 1
    fi
    
    if [ ! -f "$artifact_file" ]; then
        log_error "Artifact template file not found: $artifact_file"
        return 1
    fi
    
    log_info "Deploying policy: $policy_name"
    log_info "Policy definition: $policy_def_file"
    log_info "Artifact template: $artifact_file"
    
    # Deploy the policy via REST API (using correct field names from WSO2 docs)
    DEPLOY_RESPONSE=$(curl $CURL_INSECURE -s -w "%{http_code}" -X POST "https://$APIM_HOST:$APIM_PORT/api/am/publisher/v4/operation-policies" \
    -H "Authorization: Bearer $access_token" \
    -F "policySpecFile=@$policy_def_file" \
    -F "synapsePolicyDefinitionFile=@$artifact_file")

    log_info "Using token: ${access_token:0:20}..."

    # Extract HTTP code (last 3 characters)
    HTTP_STATUS="${DEPLOY_RESPONSE: -3}"
    # Extract response body (everything except last 3 characters)
    RESPONSE_BODY="${DEPLOY_RESPONSE%???}"
    
    if [ "$HTTP_STATUS" -eq 201 ] || [ "$HTTP_STATUS" -eq 200 ]; then
        POLICY_ID=$(echo "$RESPONSE_BODY" | jq -r '.id // empty')
        log_success "  ✓ Policy deployed successfully"
        if [ -n "$POLICY_ID" ] && [ "$POLICY_ID" != "null" ]; then
            log_info "  Policy ID: $POLICY_ID"
        fi
        return 0
    elif [ "$HTTP_STATUS" -eq 500 ] && echo "$RESPONSE_BODY" | grep -q "Existing common operation policy found for the same name"; then
        log_success "  ✓ Policy already exists (skipped duplicate)"
        return 2  # Return 2 to indicate already installed
    elif [ "$HTTP_STATUS" -eq 409 ]; then
        log_success "  ✓ Policy already exists (conflict - skipped duplicate)"
        return 2  # Return 2 to indicate already installed
    else
        log_error "  ✗ Failed to deploy policy (HTTP $HTTP_STATUS)"
        log_info "  Response: $RESPONSE_BODY"
        return 1
    fi
}

# Function to extract policy files from distribution ZIP
extract_policy_files() {
    local zip_file="$1"
    local extract_dir="$2"
    
    log_info "Extracting policy files from: $(basename "$zip_file")"
    
    # Create extraction directory
    mkdir -p "$extract_dir"
    
    # Special case for azure-content-safety-guardrail which has files in content-moderation subdirectory
    if [[ "$(basename "$zip_file")" == *"azure-content-safety-guardrail"* ]]; then
        if unzip -j -o "$zip_file" "content-moderation/policy-definition.json" "content-moderation/artifact.j2" -d "$extract_dir" >> "$INSTALL_LOG" 2>&1; then
            return 0
        else
            log_error "Failed to extract azure-content-safety-guardrail files from content-moderation subdirectory"
            return 1
        fi
    else
        # Standard extraction for other policies
        if unzip -j -o "$zip_file" "policy-definition.json" "artifact.j2" -d "$extract_dir" >> "$INSTALL_LOG" 2>&1; then
            return 0
        else
            log_error "Failed to extract policy files from ZIP"
            return 1
        fi
    fi
}

# Main policy installation process
log_header "Starting policy installation..."
echo ""

# Get access token
log_info "Attempting to obtain access token..."
ACCESS_TOKEN=$(get_access_token)
TOKEN_RESULT=$?

if [ -n "$ACCESS_TOKEN" ]; then
    log_info "Access token length: ${#ACCESS_TOKEN}"
else
    log_info "Access token is empty"
fi

if [ $TOKEN_RESULT -ne 0 ] || [ -z "$ACCESS_TOKEN" ]; then
    log_error "Failed to obtain access token. Cannot proceed with policy installation."
    log_error "Token result code: $TOKEN_RESULT"
    exit 1
fi

log_success "✓ Access token obtained successfully"

echo ""

# Find all distribution ZIP files
log_info "Searching for policy distribution ZIP files..."
DISTRIBUTION_ZIPS=($(find "$PROJECT_ROOT/mediation/ai" -name "*-distribution.zip" -type f))

if [ ${#DISTRIBUTION_ZIPS[@]} -eq 0 ]; then
    log_error "No distribution ZIP files found. Please run the build script first:"
    log_info "  ./build-all-policies.sh"
    exit 1
fi

log_info "Found ${#DISTRIBUTION_ZIPS[@]} distribution ZIP files"

# Create temporary directory for extracted policy files
TEMP_EXTRACT_DIR="$BUILD_OUTPUT_DIR/policy-extracts"
rm -rf "$TEMP_EXTRACT_DIR"
mkdir -p "$TEMP_EXTRACT_DIR"

# Installation statistics
SUCCESSFUL_INSTALLS=0
ALREADY_INSTALLED=0
FAILED_INSTALLS=0
TOTAL_POLICIES=${#DISTRIBUTION_ZIPS[@]}

log_info "Extracting and installing $TOTAL_POLICIES policies..."
echo ""

# Process each distribution ZIP
for zip_file in "${DISTRIBUTION_ZIPS[@]}"; do
    # Extract policy name from ZIP file path
    # Path format: .../mediation/ai/{policy-name}/universal-gw/{policy-name}/target/{policy-name}-distribution.zip
    policy_name=$(echo "$zip_file" | sed 's|.*/mediation/ai/\([^/]*\)/.*|\1|')
    
    log_header "Processing: $policy_name"
    
    # Create extraction directory for this policy
    policy_extract_dir="$TEMP_EXTRACT_DIR/$policy_name"
    
    # Extract policy files from ZIP
    if extract_policy_files "$zip_file" "$policy_extract_dir"; then
        log_success "  ✓ Policy files extracted successfully"
        
        # Deploy the policy
        deploy_policy "$policy_name" "$policy_extract_dir" "$ACCESS_TOKEN" || deploy_result=$?
        case ${deploy_result:-0} in
            0)
                ((SUCCESSFUL_INSTALLS++))
                ;;
            2)
                ((ALREADY_INSTALLED++))
                ;;
            *)
                ((FAILED_INSTALLS++))
                ;;
        esac
    else
        log_error "  ✗ Failed to extract policy files"
        ((FAILED_INSTALLS++))
    fi
    
    echo ""
done

# Cleanup temporary directory
#log_info "Cleaning up temporary files..."
#
#rm -rf "$TEMP_EXTRACT_DIR"

# Installation summary
echo "============================================"
log_header "Installation Summary:"
log_info "Total policies: $TOTAL_POLICIES"

if [ $SUCCESSFUL_INSTALLS -gt 0 ]; then
    log_success "Newly installed: $SUCCESSFUL_INSTALLS"
fi

if [ $ALREADY_INSTALLED -gt 0 ]; then
    log_success "Already installed: $ALREADY_INSTALLED"
fi

if [ $FAILED_INSTALLS -gt 0 ]; then
    log_error "Failed: $FAILED_INSTALLS"
else
    log_success "Failed: $FAILED_INSTALLS"
fi

echo ""
log_info "Installation log available at: $INSTALL_LOG."

log_info "For more usage options, run: ./install-policies.sh --help"
echo ""

# Final timestamp
echo "" >> "$INSTALL_LOG"
echo "Installation completed at: $(date)" >> "$INSTALL_LOG"

# Clear sensitive variables from memory
unset ADMIN_PASS
unset ACCESS_TOKEN

# Exit with error code if any installations failed
if [ $FAILED_INSTALLS -gt 0 ]; then
    exit 1
else
    log_success "All policies installed successfully!"
    echo ""
    log_info "You can verify the installation by connecting to:"
    log_info "  https://$APIM_HOST:$APIM_PORT/publisher"
    log_info "  Navigate to: Policies → Operation Policies of any AI/LLM API"
    echo ""
    exit 0
fi